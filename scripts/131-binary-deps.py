#!/usr/bin/env python3
"""
/system/bin binairelerinin HANGI kutuphanelere bagli oldugunu cikarir ve
Huawei kutuphanesi gerektirenleri isaretler.

Amac: "38 binary calisiyor" sonucunu tamamlamak. toybox yalnizca AOSP
kutuphaneleri yukledigi icin Huawei kutuphaneleri denenmedi. Bu tarama,
Huawei'e bagli binaireleri (HwServiceHost, AGPService vb.) isaret eder.
"""
import os, subprocess, re, collections

TREE = "/root/harmony-build/tree"
BIN = f"{TREE}/system/bin"
OUT = "../analysis"

HUAWEI_RE = re.compile(
    r"^lib(hw[a-z]|hms|hwid|hisilicon|his[ie]|kirin|huawei|hwnet|"
    r"ace|idc|ispr|ims|mm|cam|isp|dfx|ace|msp|ohos|arkts|"
    r"iGraphicsCore|vpustudio|vnware)", re.I)


def needed(path):
    try:
        r = subprocess.run(
            ["aarch64-linux-gnu-readelf", "-d", path],
            capture_output=True, text=True, timeout=20)
        return re.findall(r"NEEDED.*?\[(.+?)\]", r.stdout)
    except Exception:
        return []


def main():
    bins = []
    for d in (BIN, f"{TREE}/system/bin"):
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            p = os.path.join(d, fn)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            try:
                with open(p, "rb") as f:
                    if f.read(4) != b"\x7fELF":
                        continue
            except OSError:
                continue
            bins.append((fn, p))
        break

    print(f"ELF binary taramasi: {len(bins)}\n")

    huawei_bins = []
    dep_count = collections.Counter()

    for fn, p in bins:
        nd = needed(p)
        hw = [x for x in nd if HUAWEI_RE.match(x)]
        for x in nd:
            dep_count[x] += 1
        if hw:
            huawei_bins.append((fn, hw, len(nd)))

    print(f"Huawei kutuphanesi gerektiren binary: {len(huawei_bins)}\n")
    for fn, hw, tot in sorted(huawei_bins, key=lambda x: -len(x[1]))[:30]:
        print(f"  {fn:<28} {len(hw):>2}/{tot:<3} Huawei  -> {', '.join(hw[:3])}"
              + (" ..." if len(hw) > 3 else ""))

    # En cok kullanilan kutuphaneler
    print("\n--- en cok bagimli olunan kutuphaneler (top 20) ---")
    for lib, c in dep_count.most_common(20):
        mark = " *HUAWEI*" if HUAWEI_RE.match(lib) else ""
        print(f"  {c:>4}  {lib}{mark}")

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "binary-deps.tsv"), "w", encoding="utf-8") as f:
        f.write("binary\thuawei_deps\ttotal_deps\tall\n")
        for fn, p in bins:
            nd = needed(p)
            hw = [x for x in nd if HUAWEI_RE.match(x)]
            f.write(f"{fn}\t{len(hw)}\t{len(nd)}\t{','.join(nd)}\n")
    print(f"\ncikti: {OUT}/binary-deps.tsv")


if __name__ == "__main__":
    main()