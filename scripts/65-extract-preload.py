#!/usr/bin/env python3
"""Ikinci sparse container'dan EROFS bolumlerini cikar.

Neden ayri bir adim? Ilk container'da (super) LP metadata ile bolumleri
dilimledik ama vendor/odm/cust o super'da DEGIL -- extent'leri bosluga
(islenmemis DONT_CARE alanina) bakiyordu.

Ikinci sparse adayi (0x1be50106) ham veri olarak tam olarak
  vendor 962 MB + odm 646 MB + cust 88 MB = 1.696 GB
tasiyor; ilk super'in ham verisi ise sadece 4.711 GB ile kesiliyor.
Dolayisiyla eksik bolumler burada.

LP metadata yok, ama EROFS superblock'inin kendisi yeter: EROFS'de sihirli
bavt bolumun 1024. baytindadir ve superblock `blocks` x `1<<blkszbits` ile
bolumun gercek boyutunu verir.
"""
import struct, mmap, os

APP = "/root/harmony-build/noh-payload/UPDATE.APP"
OUT = "/root/harmony-build/super-out"
RAW = os.path.join(OUT, "super2.raw")
SPARSE_MAGIC = 0xED26FF3A
RAW_T, FILL_T, DONT, CRC = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4


def log(m):
    print(m, flush=True)


def _has_lp(mm, start):
    """Adayin govdesinde gecerli LP metadata var mi? (super ayirt edici)"""
    _m, _a, _b, fsz, csz, _blk, _blks, nchunks, _c = \
        struct.unpack_from("<IHHHHIIII", mm, start)
    pos = start + fsz
    for _ in range(nchunks):
        ctype, _r, _cbk, ctotal = struct.unpack_from("<HHII", mm, pos)
        pos += ctotal
    end = pos
    p = start
    while True:
        i = mm.find(struct.pack("<I", 0x414C5030), p, end)
        if i == -1:
            return False
        p = i + 1
        try:
            (magic, maj, mnr, _hsz, _hc, _ts, _tc,
             _po, p_num, p_size, *_rest) = \
                struct.unpack_from("<IHH I32s I32s IIII IIII IIII", mm, i)
        except Exception:
            continue
        if maj == 10 and 1 <= p_num <= 32 and p_size == 52:
            return True
    return False


def find_second_sparse(mm, size):
    """super OLMAYAN diger 6.8 GB sparse adayini dondur.

    DIKKAT: Adaylar dosya sirasina gore gelir; sadece 'cands[1]' gibi bir
    indeksle secmek yanlis sonuc verir (super, listede 1. degil 2. olabildigi
    icin). Ayirt edici LP metadata'nin varligi: super'da LP vardir, preload
    container'inda yoktur.
    """
    off, cands = 0, []
    pat = struct.pack("<I", SPARSE_MAGIC)
    while len(cands) < 20:
        i = mm.find(pat, off)
        if i == -1:
            break
        off = i + 1
        try:
            _m, _a, _b, fsz, csz, blk, blks, ch, _c = \
                struct.unpack_from("<IHHHHIIII", mm, i)
        except Exception:
            continue
        if (fsz == 28 and csz == 12 and blk == 4096
                and 6.5 * 1024**3 < blks * blk < 7.2 * 1024**3 and 0 < ch < 100000):
            cands.append(i)

    for c in cands:
        is_super = _has_lp(mm, c)
        log(f"  aday 0x{c:012x}  LP={'var (super)' if is_super else 'yok (preload)'}")
        if not is_super:
            return c
    return None


def sparse_to_raw(mm, start, raw_path):
    _m, _a, _b, fsz, csz, blk, blks, nchunks, _c = \
        struct.unpack_from("<IHHHHIIII", mm, start)
    total = blks * blk
    pos = start + fsz
    virt = 0
    written = 0
    with open(raw_path, "wb") as o:
        o.truncate(total)
        for _ in range(nchunks):
            ctype, _r, cblk, ctotal = struct.unpack_from("<HHII", mm, pos)
            if ctype == RAW_T:
                o.seek(virt)
                mm.seek(pos + csz)
                left = cblk * blk
                while left > 0:
                    b = mm.read(min(1 << 24, left))
                    if not b:
                        break
                    o.write(b)
                    left -= len(b)
                written += cblk * blk - left
            elif ctype == FILL_T:
                pat = mm[pos + csz:pos + csz + 4]
                blkpat = pat * (cblk * blk // 4)
                o.seek(virt)
                left = len(blkpat)
                while left > 0:
                    n = min(1 << 24, left)
                    o.write(blkpat[:n])
                    left -= n
                written += cblk * blk
            virt += cblk * blk
            pos += ctotal
    return total, written


def erofs_size(mm, i):
    """EROFS sihirli bayti i -> (part_start, fs_size) veya None."""
    if i < 1024:
        return None
    sb = i  # superblock 1024. baytta baslar
    magic, _csum, _fc = struct.unpack_from("<III", mm, sb)
    if magic != 0xE0F5E1E0:
        return None
    blkszbits = mm[sb + 12]
    if not (9 <= blkszbits <= 16):
        return None
    blocks = struct.unpack_from("<I", mm, sb + 36)[0]
    if blocks == 0 or blocks > (16 * 1024**3 >> blkszbits):
        return None
    return i - 1024, blocks * (1 << blkszbits), blkszbits, blocks


def main():
    log(f"UPDATE.APP aciliyor ({os.path.getsize(APP):,} bayt)")
    with open(APP, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        size = os.path.getsize(APP)
        s2 = find_second_sparse(mm, size)
        if s2 is None:
            log("HATA: ikinci sparse bulunamadi")
            return 1
        log(f"ikinci sparse @ 0x{s2:012x}")

        if not (os.path.exists(RAW) and os.path.getsize(RAW) > 6.5 * 1024**3):
            log("\n[1] sparse -> raw cevriliyor...")
            total, written = sparse_to_raw(mm, s2, RAW)
            log(f"  raw={total/1024**3:.3f} GB  yazilan={written/1024**3:.3f} GB")
        else:
            log(f"\n[1] {RAW} zaten var, atlandi")
        mm.close()

    log("\n[2] EROFS bolumleri araniyor ve kesiliyor...")
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
            r = erofs_size(mm, i)
            if r:
                found.append(r)
        mm.close()

    log(f"  {len(found)} gecerli EROFS bulundu")
    for n, (pstart, fssz, bits, blocks) in enumerate(sorted(found)):
        if pstart + fssz > size:
            log(f"  [{n}] atlandi (super.raw tasar): 0x{pstart:x}")
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
        log(f"  [{n}] 0x{pstart:010x}  {fssz/1024**3:7.3f} GB  "
            f"blok={blocks} -> {os.path.basename(dst)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())