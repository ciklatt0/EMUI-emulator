#!/usr/bin/env python3
"""
Huawei kutuphanelerinden disa ACIL API yuzeyini cikar.

Neden?  Bir kutuphanenin degeri, disa sundugu API'de. Sozde (dynamic) sembol
tablosu (.dynsym) strip edilmis kodda bile korunur -- bu yuzden "stripped"
kutuphanelerde bile API'yi gormek mumkun.

Cikti:
  huawei-native-api.txt   -- C/C++ API (demangled)
  huawei-java-api.txt     -- Java API (Huawei jar'larindaki sinif/method)
"""
import os, re, subprocess, sys

TREE = "/root/harmony-build/tree"
OUT = "../analysis"
INDEX = os.path.join(OUT, "library-index.tsv")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def huawei_libs():
    """120-library-scan.py'in urettigi indeksten Huawei sinifindakiler."""
    out = []
    with open(INDEX, encoding="utf-8") as f:
        next(f)  # baslik
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) < 5:
                continue
            cls, area, arch, _kb, path = p[0], p[1], p[2], p[3], p[4]
            if cls.startswith("huawei"):
                out.append((cls, area, arch, path))
    return out


def dynsyms(path):
    """Disa acik (GLOBAL/WEAK, UND olmayan) semboller."""
    try:
        r = subprocess.run(["readelf", "--dyn-syms", "--wide", path],
                           capture_output=True, text=True, timeout=60)
        return r.stdout
    except Exception:
        return ""


FUNC_RE = re.compile(
    r"^\s*\d+:\s+([0-9a-f]+)\s+\d+\s+(FUNC|OBJECTIF?C?T?YPE)\s+"
    r"(GLOBAL|WEAK)\s+\S+\s+(\S+)\s+(.+)$")


def demangle(names):
    if not names:
        return []
    try:
        r = subprocess.run(["c++filt"], input="\n".join(names),
                           capture_output=True, text=True, timeout=60)
        return r.stdout.split("\n")
    except Exception:
        return names


def native_api():
    libs = huawei_libs()
    # Ayni ismin 32/64-bit kopyalari var; tekilleştir
    seen = {}
    for cls, area, arch, path in libs:
        seen.setdefault(path.split("/")[-1], path)
    libs = sorted(seen.values())

    print(f"Huawei kutuphanesi (tekillestirilmis): {len(libs)}")

    total = 0
    with open(os.path.join(OUT, "huawei-native-api.txt"), "w",
              encoding="utf-8") as out:
        out.write("# HarmonyOS / Huawei - native disa acik API yuzeyi\n")
        out.write(f"# kutuphane: {len(libs)}\n")
        out.write("# uretim: scripts/121-export-api.py\n\n")

        for rel in libs:
            fp = os.path.join(TREE, rel)
            if not os.path.exists(fp):
                continue
            txt = dynsyms(fp)
            if not txt:
                continue

            raw, vers = [], []
            for line in txt.split("\n"):
                m = FUNC_RE.match(line)
                if not m:
                    continue
                _addr, _typ, _bind, _ndx, name = m.groups()
                name = name.strip()
                if not name:
                    continue
                base = name.split("@")[0]      # @LIBC gibi surum at
                raw.append(base)
                vers.append(name)
            if not raw:
                continue

            # versioned olmayan benzersiz adlar, demangle
            uniq_raw = sorted(set(raw))
            dem = demangle(uniq_raw)
            total += len(uniq_raw)

            out.write(f"\n{'='*74}\n{rel}\n{'='*74}\n")
            for i, name in enumerate(dem):
                out.write(name + "\n")

    print(f"toplam disa acik sembol: {total}")
    print(f"cikti: {OUT}/huawei-native-api.txt")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    native_api()