#!/usr/bin/env python3
"""Cikarilan bolumlerin gercekten dosya sistemi icerdigini dogrula.

Onemli: EROFS'de sihirli bayt bolumun 0'inda degil, 1024'te (superblock
struct'inin ilk alani) bulunur. Bu yuzden yalnizca ilk bayta bakmak
yanlis negatif verir -- ilk 64 KB taranir.
"""
import os, mmap

PARTS = "/root/harmony-build/lio-super-out/parts"
SCAN = 64 * 1024

SIGS = [
    (b"\xe2\xe1\xf5\xe0", "EROFS"),
    (b"\x53\xef",         "ext2/3/4"),
    (b"\x91\x23\x68\x3e", "btrfs"),
    (b"\xf2\xf5\x20\x10", "f2fs"),
    (b"\x10\x00\x00\x01", "ext2(le)"),
    (b"\x1f\x8b",         "gzip"),
    (b"\x78\x01",         "zlib"),
    (b"ANDROID!",         "boot image"),
    (b"\x3a\xff\x26\xed", "sparse"),
    (b"AVB0",             "AVB footer"),
    (b"CRYP",             "fscrypt"),
]

print(f"{'bolum':<14} {'boyut':>10}  {'bulunan':<12} {'ofset':>8}")
print("-" * 52)

for name in sorted(os.listdir(PARTS)):
    p = os.path.join(PARTS, name)
    sz = os.path.getsize(p)
    found, foff = None, None
    with open(p, "rb") as f:
        head = f.read(SCAN)
    for sig, tag in SIGS:
        i = head.find(sig)
        if i != -1 and (found is None or i < foff):
            found, foff = tag, i
    off_s = f"+{foff}" if foff is not None else "-"
    print(f"{name.replace('.img',''):<14} {sz/1024**3:>7.3f} GB  "
          f"{(found or '-- yok --'):<12} {off_s:>8}")

print()
print("Beklenen: hepsi EROFS @ +1024")
print("(HarmonyOS 3 = Android 12 tabani, salt-okunur sistem -> EROFS)")