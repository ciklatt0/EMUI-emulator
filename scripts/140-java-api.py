#!/usr/bin/env python3
"""
HarmonyOS Java API yuzeyini cikarir (.jar / .vdex / .apk icindeki DEX).

Neden kendi yazacimiz? Android build-tools icindeki dexdump/apkanalyzer
gerektiriyor ve bazi surumler Java bagimliligi ister. Burada gereken sadece
DEX'in string/type/proto/method tablolari -- tam bir cozumleyici degil.
Ustelik .vdex dosyalari da ayni tablolari iceriyor (VDEX = header + dex).

Cikti:
  huawei-java-api.txt   sinif + metot imzalari (yalnizca Huawei'e ait olanlar)
  java-api-all.txt      tum framework API'si
"""
import os, struct, zipfile, io, sys, re

TREE = "/root/harmony-build/tree"
FRAMEWORK = f"{TREE}/system/framework"
APEX_JARS = [
    f"{TREE}/apex/com.android.art/framework",
    f"{TREE}/apex/com.android.art",
]
OUT = "../analysis"

HUAWEI_PKG = re.compile(
    r"(com/huawei|com/hw|ohos/|com/huawei/|ohos/|com/qihoo|"
    r"huawei)", re.I)


# Gecerli Java tanimlayicisi mi? DEX string havuzunda derleyici artiklari da
# bulunur ("Chyba: nie zaimplementowany <init>()" gibi Lehce hata metinleri).
# Bunlar method_ids tarafindan referanslandiginda metot adi gibi gorunur ama
# gercek API degildir. Ciktiyi kullanilabilir kilmak icin eleniriz.
JAVA_IDENT = re.compile(r"^[A-Za-z_$][A-Za-z0-9_$]*$")


def sane_method(nm):
    return bool(nm) and JAVA_IDENT.match(nm) and len(nm) < 200


# ---------------------------------------------------------------- DEX okuma
class Dex:
    def __init__(self, data):
        self.d = data
        if data[:4] != b"dex\n":
            raise ValueError("DEX imzasi yok")
        # DEX header 112 bayt; ilk 32 bayt imza+checksum+signature'dir.
        # DIKKAT: 20 adet uint32 alan 0x20 (32) ofsetten BASLAR. "<I8x20I"
        # yazimi alanlari 12. bayttan baslatir ve tum degerleri kaydirir --
        # sessizce yanlis tablo ofsetleri uretir.
        #   0x00 magic[8]  0x08 checksum  0x0C signature[20]  -> 0x20 buraya gelir
        h = struct.unpack_from("<32x20I", data, 0)
        (self.file_size, self.header_size, self.endian, self.link_size,
         self.link_off, self.map_off, self.string_ids_size,
         self.string_ids_off, self.type_ids_size, self.type_ids_off,
         self.proto_ids_size, self.proto_ids_off, self.field_ids_size,
         self.field_ids_off, self.method_ids_size, self.method_ids_off,
         self.class_defs_size, self.class_defs_off, self.data_size,
         self.data_off) = h
        self._strings = None

    # --- MUTF-8 (DEX'e ozgu, basinda ULEB128 uzunluk) ---
    @staticmethod
    def _uleb128(d, off):
        val = shift = 0
        while True:
            b = d[off]
            off += 1
            val |= (b & 0x7F) << shift
            if not (b & 0x80):
                return val, off
            shift += 7

    def strings(self):
        if self._strings is not None:
            return self._strings
        out = []
        d = self.d
        for i in range(self.string_ids_size):
            off = struct.unpack_from("<I", d, self.string_ids_off + 4 * i)[0]
            _n, p = self._uleb128(d, off)
            # MUTF-8: 0x00 0x00 iki bayt NUL olarak kodlanir
            s = bytearray()
            while d[p] != 0:
                s.append(d[p]); p += 1
            out.append(s.decode("utf-8", errors="replace"))
        self._strings = out
        return out

    def types(self):
        st = self.strings()
        return [st[struct.unpack_from("<I", self.d, self.type_ids_off + 4 * i)[0]]
                for i in range(self.type_ids_size)]

    def type_list(self, off):
        """proto'nun parametre listesi (type_list -> type_idx dizisi)."""
        if not off:
            return []
        n = struct.unpack_from("<I", self.d, off)[0]
        return [struct.unpack_from("<H", self.d, off + 4 + 2 * i)[0]
                for i in range(n)]

    def protos(self):
        st, ty = self.strings(), self.types()
        out = []
        for i in range(self.proto_ids_size):
            shorty, ret, params_off = struct.unpack_from(
                "<III", self.d, self.proto_ids_off + 12 * i)
            ps = [ty[j] for j in self.type_list(params_off)]
            # DIKKAT: return_type_idx bir TYPE indeksidir, string indeksi DEGIL.
            # st[ret] yazilirsa donus tipi yerine string tablosundaki
            # ilgisiz bir metin gelir (derleyici artiklari, Lehce hata
            # mesajlari vb.) ve tum API yanlis gorunur.
            out.append((ty[ret], ps))
        return out

    def method_ids(self):
        """(class_desc, proto_idx, name) listesi."""
        st = self.strings()
        out = []
        for i in range(self.method_ids_size):
            cls_idx, proto_idx, name_idx = struct.unpack_from(
                "<HHI", self.d, self.method_ids_off + 8 * i)
            out.append((cls_idx, proto_idx, st[name_idx]))
        return out

    def classes(self):
        """
        sinif -> [(access, method_adi, donus_tipi, parametreler, access)]
        encoded_method'lar ULEB128 delta kodlamalidir.
        """
        ty, pr = self.types(), self.protos()
        mids = self.method_ids()
        d = self.d
        out = {}

        for i in range(self.class_defs_size):
            base = self.class_defs_off + 32 * i
            (cls_idx, access, _super, _iface, _src, _ann, _data,
             _static) = struct.unpack_from("<8I", d, base)
            cname = ty[cls_idx]
            if _data == 0:
                out[cname] = {"access": access, "methods": []}
                continue
            p = _data
            sf, p = self._uleb128(d, p)
            ifl, p = self._uleb128(d, p)
            dm, p = self._uleb128(d, p)
            vm, p = self._uleb128(d, p)
            # alanlar (atlanir)
            _idx = 0
            for _ in range(sf):
                _idx, p = self._uleb128(d, p)
                _a, p = self._uleb128(d, p)
            _idx = 0
            for _ in range(ifl):
                _idx, p = self._uleb128(d, p)
                _a, p = self._uleb128(d, p)
            # metotlar
            idx = 0
            ms = []
            for kind, cnt in (("direct", dm), ("virtual", vm)):
                for _ in range(cnt):
                    diff, p = self._uleb128(d, p)
                    acc, p = self._uleb128(d, p)
                    code, p = self._uleb128(d, p)
                    idx += diff
                    if idx < len(mids):
                        c, pi, nm = mids[idx]
                        # DIKKAT: protos() parametreleri ZATEN tip tanimlayicisina
                        # cevirmis oluyor. Burada ikinci kez ty[] ile indekslemek
                        # string'i listeye indexlemeye calisir -> TypeError.
                        ret, ps = pr[pi]
                        if not sane_method(nm):
                            continue      # derleyici artigi / bozuk kayit
                        ms.append((nm, ret, ps, acc))
            out[cname] = {"access": access, "methods": ms}
        return out


def jname(desc):
    """Landroid/app/Activity; -> android.app.Activity"""
    if desc.startswith("L") and desc.endswith(";"):
        return desc[1:-1].replace("/", ".")
    if desc.startswith("["):
        return jname(desc[1:]) + "[]"
    return {"V": "void", "I": "int", "Z": "boolean", "J": "long",
            "F": "float", "D": "double", "B": "byte", "S": "short",
            "C": "char"}.get(desc, desc)


def load_dex_blobs(path):
    """jar/vdex/apk icinden tum dex govdelerini dondurur."""
    blobs = []
    try:
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                if n.endswith(".dex"):
                    blobs.append((n, z.read(n)))
    except zipfile.BadZipFile:
        # VDEX: header'dan sonra gomulu dex'ler var
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError:
            return blobs
        pos = 0
        while True:
            i = data.find(b"dex\n", pos)
            if i == -1:
                break
            size = struct.unpack_from("<I", data, i + 32)[0]
            if 0 < size <= len(data) - i:
                blobs.append((f"dex@{i:#x}", data[i:i + size]))
                pos = i + size
            else:
                pos = i + 1
    return blobs


def main():
    os.makedirs(OUT, exist_ok=True)

    jars = []
    for d in [FRAMEWORK] + APEX_JARS:
        if os.path.isdir(d):
            for fn in sorted(os.listdir(d)):
                if fn.endswith((".jar", ".apk", ".vdex")):
                    jars.append(os.path.join(d, fn))

    print(f"taranan arsiv: {len(jars)}")

    all_rows, huawei_rows = [], []
    ok, fail = 0, 0

    for path in jars:
        for name, blob in load_dex_blobs(path):
            try:
                dx = Dex(blob)
                cls = dx.classes()
            except Exception as e:
                fail += 1
                continue
            ok += 1
            base = os.path.basename(path)
            for cname, info in cls.items():
                if not cname.startswith("L"):
                    continue
                pkg = cname[1:].split("/")[0]
                is_hw = bool(HUAWEI_PKG.search(cname))
                cn = jname(cname)
                row = {"jar": base, "cls": cn, "access": info["access"],
                       "methods": info["methods"]}
                all_rows.append(row)
                if is_hw:
                    huawei_rows.append(row)

    print(f"cozulen dex : {ok}   (hata: {fail})")
    print(f"toplam sinif: {len(all_rows)}")
    print(f"Huawei sinif: {len(huawei_rows)}")

    def write(path, rows, title):
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"# {title}\n# {len(rows)} sinif\n")
            f.write("# uretim: scripts/140-java-api.py\n\n")
            for r in sorted(rows, key=lambda x: x["cls"]):
                f.write(f"\n{'='*72}\n{r['cls']}   [{r['jar']}]\n{'='*72}\n")
                for nm, ret, ps, acc in r["methods"]:
                    ps_s = ", ".join(jname(x) for x in ps)
                    f.write(f"  {jname(ret)} {nm}({ps_s})\n")

    write(os.path.join(OUT, "huawei-java-api.txt"), huawei_rows,
          "HarmonyOS / Huawei - Java API yuzeyi")
    write(os.path.join(OUT, "java-api-all.txt"), all_rows,
          "Tum framework Java API yuzeyi")

    print(f"\ncikti: {OUT}/huawei-java-api.txt")
    print(f"       {OUT}/java-api-all.txt")

    print("\n--- Huawei'e ait en buyuk 15 sinif ---")
    for r in sorted(huawei_rows, key=lambda x: -len(x["methods"]))[:15]:
        print(f"  {len(r['methods']):>4} metot  {r['cls']}")


if __name__ == "__main__":
    main()