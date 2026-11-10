#!/usr/bin/env python3
"""
LIO-AN00 preload UPDATE.APP'inden tek EROFS bolumunu cikar.

Preload paketi ikinci super sparse image'i ICERMEZ. Bunun yerine tek bir
sparse chunk var ve icinde EROFS dosya sistemi (vendor veya odm).

Akis:
  1. Sparse magic (0xED26FF3A) bul
  2. Sparse header'i oku (28 bayt)
  3. Chunk'lari parse et, RAW veriyi ham dosyaya yaz
  4. Cikan ham dosyada EROFS magic'i ara, bolumu kes
"""
import struct, mmap, os, sys

APP = "/root/harmony-build/lio-payload/base-UPDATE.APP"
OUT = "/root/harmony-build/lio-super-out"
RAW = os.path.join(OUT, "preload-raw.img")
SPARSE_MAGIC = 0xED26FF3A
RAW_T = 0xCAC1

HDR = "<IHHHHIIII"


def log(m):
    print(m, flush=True)


def main():
    log(f"UPDATE.APP aciliyor: {APP} ({os.path.getsize(APP):,} bayt)")
    with open(APP, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        size = os.path.getsize(APP)

        pat = struct.pack("<I", SPARSE_MAGIC)
        start = mm.find(pat)
        if start == -1:
            log("HATA: sparse magic bulunamadi")
            return 1

        _m, _ma, _mi, fsz, csz, blk, blks, nchunks, _cs = \
            struct.unpack_from(HDR, mm, start)
        log(f"  sparse @ 0x{start:012x}  header={fsz} chunk_hdr={csz} "
            f"blk={blk} bloklar={blks} chunkler={nchunks}")
        log(f"  sanal boyut: {blks * blk / 1024**3:.3f} GB")

        os.makedirs(OUT, exist_ok=True)
        total = blks * blk
        written = 0
        with open(RAW, "wb") as o:
            o.truncate(total)
            pos = start + fsz
            virt = 0
            for n in range(nchunks):
                ctype, _r, cblk, ctotal = struct.unpack_from("<HHII", mm, pos)
                if ctype == RAW_T:
                    data_off = pos + csz
                    data_len = cblk * blk
                    mm.seek(data_off)
                    o.seek(virt)
                    left = data_len
                    while left > 0:
                        n_ = min(1 << 24, left)
                        buf = mm.read(n_)
                        if not buf:
                            break
                        o.write(buf)
                        left -= len(buf)
                    written += data_len - left
                virt += cblk * blk
                pos += ctotal
        log(f"  ham veri yazildi: {written / 1024**3:.3f} GB -> {RAW}")
        mm.close()

    log("\nEROFS bolumleri araniliyor...")
    os.makedirs(os.path.join(OUT, "parts2"), exist_ok=True)
    pdir = os.path.join(OUT, "parts2")
    for old in os.listdir(pdir):
        os.remove(os.path.join(pdir, old))

    size = os.path.getsize(RAW)
    found = []
    with open(RAW, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        pos = 0
        while True:
            i = mm.find(b"\xe2\xe1\xf5\xe0", pos)
            if i == -1:
                break
            pos = i + 1
            if i < 1024:
                continue
            sb = i
            magic, _csum, _fc = struct.unpack_from("<III", mm, sb)
            if magic & 0xFFFFFF00 != 0xE0F5E100:
                continue
            blkszbits = mm[sb + 12]
            if not (9 <= blkszbits <= 16):
                continue
            blocks = struct.unpack_from("<I", mm, sb + 36)[0]
            if blocks == 0 or blocks > (16 * 1024**3 >> blkszbits):
                continue
            fs_start = i - 1024
            fs_size = blocks * (1 << blkszbits)
            found.append((fs_start, fs_size, blkszbits, blocks))
        mm.close()

    log(f"  {len(found)} gecerli EROFS bulundu")
    for n, (pstart, fssz, bits, blocks) in enumerate(found):
        if pstart + fssz > size:
            log(f"  [{n}] atlandi (tasar): 0x{pstart:x}")
            continue
        dst = os.path.join(pdir, f"part{n}_{pstart:010x}.img")
        with open(RAW, "rb") as fi, open(dst, "wb") as o:
            fi.seek(pstart)
            left = fssz
            while left > 0:
                b = fi.read(min(1 << 24, left))
                if not b:
                    break
                o.write(b)
                left -= len(b)
        log(f"  [{n}] 0x{pstart:010x}  {fssz/1024**3:7.3f} GB  blok={blocks} -> {os.path.basename(dst)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
