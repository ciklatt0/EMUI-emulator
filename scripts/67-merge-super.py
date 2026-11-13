#!/usr/bin/env python3
"""
Iki sparse image'i ust uste bindirerek super'i yeniden olusturur.

Sorun: UPDATE.APP icinde ayni mantiksal super bolumunun IKI sparse govdesi
var ve HIKSI bir bosluk birakiyor:

  govde 1  (0x886004d0): 3.821 GB ham  -> sanal 0 .. ~4.7 GB
  govde 2  (0x1be50106): 2.100 GB ham  -> sanal ~5.05 .. 6.4 GB

super.raw (6.812 GB sanal) yalnizca 4.711 GB veri iceriyor; arasi ve
sonrasi BOS. LP metadata'nin gösterdigi extent'ler:
  vendor  5.705 GB   <- BOS
  odm     6.668 GB   <- BOS
Bu yüzden vendor/odm dilimleri tamami sifir cikiyordu.

Cozum: ikinci govdeyi ilkinin uzerine bindir. Iyi kurallar:
  - super.raw'da veri OLAN yere dokunma (birincil kopya kazanir)
  - yalnizca super.raw'da bayt sirasi 0 olan (bos) parcalara yaz

Bu, Zygote'yi ayaga kaldirmak icin gerekli vendor bolumunu (Kirin HAL'leri)
ortaya cikarir.
"""
import os, mmap, sys

SUP1 = "/root/harmony-build/super-out/super.raw"
SUP2 = "/root/harmony-build/super-out/super2.raw"
CH = 1 << 22          # 4 MB parca


def main():
    if not os.path.exists(SUP1):
        print("HATA: super.raw yok -> 60-extract-partitions.py")
        return 1
    if not os.path.exists(SUP2):
        print("HATA: super2.raw yok -> 65-extract-preload.py")
        return 1

    s1, s2 = os.path.getsize(SUP1), os.path.getsize(SUP2)
    print(f"super.raw : {s1/1024**3:.3f} GB")
    print(f"super2.raw: {s2/1024**3:.3f} GB")

    total = min(s1, s2)
    a = open(SUP1, "r+b")
    b = open(SUP2, "rb")
    mm1 = mmap.mmap(a.fileno(), 0)
    mm2 = mmap.mmap(b.fileno(), 0, access=mmap.ACCESS_READ)

    filled = filled_bytes = pos = 0
    while pos < total:
        n = min(CH, total - pos)
        # super.raw bu parcada dolu mu?
        if mm1[pos:pos + n].count(0) != n:
            pos += n
            continue
        # bos -> ikinci govdeden doldur
        c2 = mm2[pos:pos + n]
        if c2.count(0) != n:
            a.seek(pos)
            a.write(c2)
            filled += 1
            filled_bytes += n
        pos += n

    a.flush()
    mm1.close(); mm2.close()
    a.close(); b.close()

    print(f"\ndoldurulan: {filled} parca ({filled_bytes/1024**3:.3f} GB)")

    # dogrulama
    a = open(SUP1, "rb")
    mm = mmap.mmap(a.fileno(), 0, access=mmap.ACCESS_READ)
    LP = {"system": (4096, 6733824),
          "hw_product": (6737920, 4227072),
          "cust": (10964992, 180224),
          "vendor": (11145216, 1880064),
          "odm": (13025280, 1261568)}
    print("\n%-14s %-12s %-8s %s" % ("bolum", "ofset", "EROFS", "ilk 1MB dolu"))
    ok_all = True
    for name, (ts, ns) in LP.items():
        st, ln = ts * 512, ns * 512
        if st + ln > len(mm):
            print(f"{name:<14} super.raw tasar")
            ok_all = False
            continue
        e = mm.find(b"\xe2\xe1\xf5\xe0", st, st + ln)
        nz = mm[st:st + (1 << 20)].count(0) != (1 << 20)
        print(f"{name:<14} 0x{st:010x}  {'VAR' if e!=-1 else 'yok':<8} {nz}")
        if e == -1:
            ok_all = False
    mm.close(); a.close()

    print()
    if ok_all:
        print("TUM BOLUMLER TAM. Simdi 60-extract-partitions.py tekrar calistir.")
        return 0
    print("Bazi bolumler hala eksik.")
    return 1


if __name__ == "__main__":
    sys.exit(main())