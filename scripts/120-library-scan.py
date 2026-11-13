#!/usr/bin/env python3
"""
HarmonyOS kutuphane envanteri ve siniflandirmasi.

Neden siniflandirma onemli?
  AOSP kutuphaneleri (libbinder, liblog, libcrypto ...) acik kaynak koddan
  alinabilir -- buralardan bilgi cikarmak bir sey ifade etmez.
  Huawei'in YAZDIGI kutuphaneler (libhw*, libhms*, libkirin* ...) projenin
  gercek kazani. Bunlari ayirt etmek icin tahmin yerine kutuphanenin icindeki
  telif ifadesine bakilir.

Iki sinyal birlikte kullanilir:
  1) Guclu:  ELF icinde "Huawei Technologies Co., Ltd" telif dizisi
  2) Zayif:  dosya adi oneki (libhw, libhms, libkirin ...)
  3) Ayirici: bilinen AOSP adi listesinde var mi
"""
import os, re, subprocess, sys, json

TREE = "/root/harmony-build/tree"
OUT = "../analysis"

HUAWEI_COPY = [
    b"Huawei Technologies Co., Ltd",
    b"HUAWEI",
    b"Hisilicon",
]

# AOSP/Android'ce yaygin olan kutuphane adlari (oneke gore)
AOSP_PREFIX = re.compile(
    r"^lib(android|binder|bluetooth|sqlite|z|png|jpeg|turbojpeg|webp|brotli|"
    r"crypto|ssl|gui|nativehelper|backward|input|femur|udev|staging|selinux|"
    r"mincrypt|binder_ndk|utils|utils_bits|cutils|sysutils|netutils|c|"
    r"m|d|dl|log|androidfw|storage|media|mediautils|mediandk|"
    r"EGL|GLESv1|GLESv2|GLESv3|GLES_trace|vulkan|OpenSLES|OpenMAXAL|"
    r"aaudio|camera|cameraserver|audioflinger|audiohal|stagefright|"
    r"soundpool|soundtrigger|tinyalsa|tinyxml2|xml2|icu[a-z]*|"
    r"sqlite3|expat|jsoncpp|protobuf|cutils|png|"
    r"opus|vpx|webm|yuv|aom|avcodec|omx|"
    r"ft2|harfbuzz|minikin|hwui|skia|png|"
    r"wilhelm|angle|"
    r"openssl|boring|cruy|"
    r"json|yaml|"
    r"crypto_ssl|"
    r"gui|binder_thread|"
    r"processgroup|"
    r"wilhelm|"
    r"packagelistparser|"
    r"sparse|ext4|f2fs|erofs|"
    r"sigchain|"
    r"backtrace|unwindstack|"
    r"proc_macro|zstd|lz4|lzma|brotli|"
    r"vulkan)"
)

# Huawei'e ozgu olasi ad onekleri
HUAWEI_PREFIX = re.compile(
    r"^lib(hw[a-z]|hw$|hms|hwid|hisilicon|his[ie]|hisi|kirin|huawei|"
    r"hwnet|hwap|hdf|hdfwifi|hwidevice|hwlog|hwuio|hwjson|hwconfig|"
    r"hwcamer|hwdisplay|hwcomposer|hwinput|hwaudio|hwgfx|"
    r"idec|ispr|imc_msp|ims|ivp|isp|ieee|"
    r"mm|mmblk|cam|camera_isp|hkm|himil|"
    r"dfx|ace|msp|vnware|cloud_|airplane|"
    r"hss|anno|te|ohos|arkts|jsapp|napi|"
    r"wifi_hal|wifi_hal_sprd|btaudio|bt|"
    r"hevc|avcodec_hisi|"
    r"securec|tee_|trusted|"
    r"ai_|_ai|nnrt|cnn|"
    r"magic|mag_|hwmagic|"
    r"ivp|audio_|disp_|display_|"
    r"hilog|hilogd|"
    r"rild|rpc|"
    r"f2fs_h|"
    r"emui|hwemui|hwapps)",
    re.I,
)


def scan():
    rows = []
    roots = [
        ("system/lib64", f"{TREE}/system/lib64", "arm64"),
        ("system/lib", f"{TREE}/system/lib", "arm"),
    ]
    apex_root = f"{TREE}/apex"
    if os.path.isdir(apex_root):
        for a in sorted(os.listdir(apex_root)):
            roots.append((f"apex/{a}", f"{apex_root}/{a}", "arm64"))

    for label, path, arch in roots:
        if not os.path.isdir(path):
            continue
        for dirpath, _dirs, files in os.walk(path):
            for fn in files:
                if not fn.endswith(".so"):
                    continue
                fp = os.path.join(dirpath, fn)
                try:
                    size = os.path.getsize(fp)
                except OSError:
                    continue
                rel = os.path.relpath(fp, TREE)
                rows.append({"name": fn, "path": rel,
                             "area": label, "arch": arch, "size": size,
                             "_fp": fp})
    return rows


def classify(r):
    """(sinif, gerekce)"""
    n = r["name"]
    stem = n[:-3] if n.endswith(".so") else n

    # guclu sinyal: icerik
    try:
        with open(r["_fp"], "rb") as f:
            head = f.read(300_000)
        tail_at = max(0, r["size"] - 120_000)
        if tail_at:
            f = open(r["_fp"], "rb"); f.seek(tail_at)
            head += f.read(120_000); f.close()
    except OSError:
        return "bilinmiyor", "okunamadi"

    hw_copy = any(c in head for c in HUAWEI_COPY)
    is_huawei_name = bool(HUAWEI_PREFIX.match(stem))
    is_aosp_name = bool(AOSP_PREFIX.match(stem))

    if hw_copy and not is_aosp_name:
        return "huawei", "telif"
    if hw_copy and is_aosp_name:
        return "huawei+aosp", "telif+ad"
    if is_huawei_name:
        return "huawei?", "ad"
    if is_aosp_name:
        return "aosp", "ad"
    return "bilinmiyor", "eslesme yok"


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = scan()
    print(f"taranan kutuphane: {len(rows)}\n")

    for r in rows:
        r["cls"], r["why"] = classify(r)

    buckets = {}
    for r in rows:
        buckets.setdefault(r["cls"], []).append(r)

    order = ["huawei", "huawei+aosp", "huawei?", "aosp", "bilinmiyor"]
    print(f"{'sinif':<14} {'adet':>6} {'toplam':>10}")
    print("-" * 34)
    for k in order:
        g = buckets.get(k, [])
        if not g:
            continue
        tot = sum(x["size"] for x in g) / 1024**2
        print(f"{k:<14} {len(g):>6} {tot:>8.1f} MB")

    # Huawei olanlari raporla
    hw = [r for r in rows if r["cls"].startswith("huawei")]
    hw.sort(key=lambda r: -r["size"])

    with open(os.path.join(OUT, "huawei-libraries.txt"), "w",
              encoding="utf-8") as f:
        f.write(f"# Huawei'e ait kutuphaneler ({len(hw)} adet)\n")
        f.write(f"# uretim: scripts/120-library-scan.py\n\n")
        for r in hw:
            f.write(f"{r['size']/1024:>10.1f} KB  {r['cls']:<10} "
                    f"{r['area']:<22} {r['path']}\n")

    with open(os.path.join(OUT, "library-index.tsv"), "w",
              encoding="utf-8") as f:
        f.write("class\tarea\tarch\tsize_kb\tpath\n")
        for r in sorted(rows, key=lambda x: x["path"]):
            f.write(f"{r['cls']}\t{r['area']}\t{r['arch']}\t"
                    f"{r['size']//1024}\t{r['path']}\n")

    print(f"\n--- Huawei'e ait EN BUYUK 25 ---")
    for r in hw[:25]:
        print(f"  {r['size']/1024:>9.1f} KB  {r['path']}")

    print(f"\ncikti: {OUT}/huawei-libraries.txt")
    print(f"       {OUT}/library-index.tsv")


if __name__ == "__main__":
    main()