#!/usr/bin/env python3
"""
UPDATE.APP icinden super partition'i cikar ve icindeki bolumleri dilimle.

Akis:
  1. UPDATE.APP icindeki Android sparse image'i bul (magic 0xED26FF3A)
  2. Chunk'lari dogru gezerek sparse -> raw cevir  (dikkat: kayma hatasina
     dikkat -- chunk basligi 12 bayt, hem dosya konumu hem de veri sonrasi
     konum ayrica ilerletilmeli)
  3. super icindeki LP metadata'yi oku; extent'lerden bolumlerin super
     icindeki bayt araliklarini hesapla
  4. system / vendor / odm / hw_product / cust dosyalarini kes

Cikti: <out>/super.raw  ve  <out>/parts/*.img
"""
import struct, os, sys, mmap

APP = "/root/harmony-build/lio-payload/UPDATE.APP"
OUT = "/root/harmony-build/lio-super-out"
SPARSE_MAGIC = 0xED26FF3A
LP_MAGIC = 0x414C5030
SECTOR = 512
RAW, FILL, DONT_CARE, CRC32 = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4

os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(OUT, "parts"), exist_ok=True)


def log(m):
    print(m, flush=True)


HDR = "<IHHHHIIII"   # magic, major, minor, file_hdr_sz, chunk_hdr_sz,
                     # blk_sz, total_blks, total_chunks, checksum  (28 bayt)


def read_sparse_hdr(mm, start):
    return struct.unpack_from(HDR, mm, start)


def sparse_end(mm, start, size):
    """Sparse govdesinin bittigi dosya offset'ini ve RAW veri miktarini dondur."""
    _m, _ma, _mi, fsz, csz, blk, blks, nchunks, _cs = read_sparse_hdr(mm, start)
    pos = start + fsz
    raw = 0
    for _ in range(nchunks):
        ctype, _r, cblk, ctotal = struct.unpack_from("<HHII", mm, pos)
        if ctype == RAW:
            raw += cblk * blk
        pos += ctotal
        if pos > size:
            break
    return pos, raw


def find_sparse(mm, size):
    """super sparse image'i bul.

    UPDATE.APP icinde birden fazla 6.8 GB sparse adayi var ve hepsi ayni
    boyutta. Ayirt edici kriter su: super'in icinde gecerli bir LP metadata
    bulunmasi. Adaylar arasinda LP'si olan, en cok RAW veri tasiyan secilir.
    """
    pat = struct.pack("<I", SPARSE_MAGIC)
    cands = []
    off = 0
    while len(cands) < 40:
        i = mm.find(pat, off)
        if i == -1:
            break
        off = i + 1
        try:
            _m, _ma, _mi, fsz, csz, blk, blks, ch, _cs = \
                struct.unpack_from("<IHHHHIIII", mm, i)
        except Exception:
            continue
        if (fsz == 28 and csz == 12 and blk == 4096
                and 6.5 * 1024**3 < blks * blk < 7.2 * 1024**3 and 0 < ch < 100000):
            end, raw = sparse_end(mm, i, size)
            has_lp = find_lp(mm, i, min(end + 0x100000, size)) is not None
            cands.append((has_lp, raw, i, end))

    if not cands:
        return None
    # once LP'si olanlar, sonra RAW verisi fazla olan
    cands.sort(key=lambda t: (t[0], t[1]), reverse=True)
    best = cands[0]
    for has_lp, raw, i, end in cands:
        log(f"    aday @0x{i:012x}  LP={'var' if has_lp else 'yok ':<3} "
            f"RAW={raw/1024**3:.3f} GB  govde=0x{end:012x}")
    return best[2], best[3]


def find_lp(mm, start, end):
    """super icindeki LP metadata'yi bul (sparse govdesinin icinde)."""
    pos = start
    while True:
        i = mm.find(struct.pack("<I", LP_MAGIC), pos)
        if i == -1 or i >= end:
            return None
        pos = i + 1
        try:
            (magic, maj, mnr, hsz, _hc, tsz, _tc,
             p_off, p_num, p_size, _e_off, _e_num, _e_size,
             _g_off, _g_num, _g_size, _b_off, _b_num, _b_size) = \
                struct.unpack_from("<IHH I32s I32s IIII IIII IIII", mm, i)
        except Exception:
            continue
        if maj == 10 and 1 <= p_num <= 32 and p_size == 52:
            return i
    return None


def sparse_to_raw(mm, start, raw_path):
    """Chunk'lari dogru gezerek ham (raw) super uret. Donen: ham boyut."""
    _m, _ma, _mi, fsz, csz, blk, blks, nchunks, _cs = read_sparse_hdr(mm, start)
    total = blks * blk
    log(f"  blok={blk} bloklar={blks} -> ham {total/1024**3:.3f} GB, {nchunks} chunk")

    written = 0
    with open(raw_path, "wb") as o:
        # Bosluk: super'in basinda DONT_CARE olabilir
        o.truncate(total)

        pos = start + fsz
        # super icindeki sanal konum (bayt)
        virt = 0
        for n in range(nchunks):
            ctype, _r, cblk, ctotal = struct.unpack_from("<HHII", mm, pos)
            if ctype == RAW:
                data_off = pos + csz
                data_len = cblk * blk
                mm.seek(data_off)
                left = data_len
                o.seek(virt)
                while left > 0:
                    n_ = min(1 << 24, left)
                    buf = mm.read(n_)
                    if not buf:
                        break
                    o.write(buf)
                    left -= len(buf)
                written += data_len - left
            elif ctype == FILL:
                # 4 baytlik desen: tum hedefi bu degerle doldur
                pat = mm[pos + csz:pos + csz + 4]
                o.seek(virt)
                blkpat = pat * (cblk * blk // 4)
                left = len(blkpat)
                while left > 0:
                    n_ = min(1 << 24, left)
                    o.write(blkpat[:n_])
                    left -= n_
                written += cblk * blk
            # DONT_CARE / CRC32: hedef zaten bos (truncate)
            virt += cblk * blk
            pos += ctotal
        log(f"  yazilan ham veri: {written/1024**3:.3f} GB")
    return total


def find_lp_in_raw(raw_path):
    """super.raw icindeki gecerli LP metadata'yi bul.

    Daha onceden hesaplanmis bir offset KULLANILMAZ: o offset UPDATE.APP
    dosya uzayinda gecerli, super.raw ise sparse -> raw cevrimi sonrasi
    farkli bir uzayda (DONT_CARE bosluklar acilmis halde). Bu yuzden sihirli
    bayti super.raw'un icinde arayip dogruluyoruz.
    """
    with open(raw_path, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        pos, found = 0, None
        while True:
            i = mm.find(struct.pack("<I", LP_MAGIC), pos)
            if i == -1:
                break
            pos = i + 1
            try:
                (magic, maj, mnr, hsz, _hc, tsz, _tc,
                 p_off, p_num, p_size, _e_off, _e_num, _e_size,
                 _g_off, _g_num, _g_size, _b_off, _b_num, _b_size) = \
                    struct.unpack_from("<IHH I32s I32s IIII IIII IIII", mm, i)
            except Exception:
                continue
            # gercek LP metadata v10: 1..32 partition, kayit boyutu 52
            if maj == 10 and 1 <= p_num <= 32 and p_size == 52:
                found = i
                break
        mm.close()
    return found


def slice_partitions(raw_path, lp_abs_off):
    """LP metadata'daki extent'lere gore bolumleri kes."""
    size = os.path.getsize(raw_path)
    with open(raw_path, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        (magic, maj, mnr, hsz, _hc, tsz, _tc,
         p_off, p_num, p_size, e_off, e_num, e_size,
         _g_off, _g_num, _g_size, _b_off, _b_num, _b_size) = \
            struct.unpack_from("<IHH I32s I32s IIII IIII IIII", mm, lp_abs_off)
        base = lp_abs_off + hsz
        parts = []
        for i in range(p_num):
            e = base + p_off + i * p_size
            # DIKKAT: LpMetadataPartition.name 72 baytlik UTF-16 DEGIL, 36 baytlik
            # duz ASCII'dir. UTF-16 olarak okunursa isimler bozulur ve (daha kotusu)
            # extent indeksleri de yanlis yere shift olur, boyutlar 0.000 GB cikar.
            name = mm[e:e + 36].split(b"\x00")[0].decode("utf-8", errors="ignore")
            if not name or not name.isprintable():
                continue
            # name[36] + attributes(4) + first_extent_index(4) + num_extents(4) + group_index(4)
            _attr, first_ext, num_ext, _grp = struct.unpack_from("<IIII", mm, e + 36)
            parts.append((name, first_ext, num_ext))

        # Blok cihazinin ilk mantiksal sektoru. Extent'lerdeki target_data
        # BU degerden itibaren sayilir; super'in basindan degil. Bu atlanirsa
        # tum dilimler LP metadata bolgesine denk gelir ve tamami sifir cikar.
        first_lsa = 0
        if _b_num:
            bo = base + _b_off
            first_lsa = struct.unpack_from("<I", mm, bo)[0]
        mm.close()

    log(f"  blok cihazi first_logical_sector = {first_lsa} "
        f"(extent ofsetlerine eklenacak)")

    log(f"  LP metadata @ 0x{lp_abs_off:x}  -> {len(parts)} bolum")

    # Eski/bozuk ciktilari temizle (isim cozumunden onceki kosudan kalanlar)
    pdir = os.path.join(OUT, "parts")
    for old in os.listdir(pdir):
        os.remove(os.path.join(pdir, old))
        log(f"  (eski cikti silindi: {old})")

    total_out = 0
    for name, first_ext, num_ext in parts:
        with open(raw_path, "rb") as f:
            mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
            exts = []
            for x in range(num_ext):
                eo = base + e_off + (first_ext + x) * e_size
                # DIKKAT: LpMetadataExtent'te target_type (u32) sonrasi u64
                # hizasi icin 4 BAYT DOLGU vardir. target_data offset 12'de
                # baslar, offset 8'de DEGIL. 8'den okunursa sistem iki yerden
                # bozulur: yanlis ofset + boslukta kalma.
                ns = struct.unpack_from("<Q", mm, eo)[0]
                td = struct.unpack_from("<Q", mm, eo + 12)[0]
                exts.append((ns, td))
            mm.close()

            outp = os.path.join(OUT, "parts", f"{name}.img")
            written = 0
            with open(outp, "wb") as o:
                for ns, td in exts:
                    # target_data zaten super'in basindan itibaren sayilan
                    # mutlak sektor numarasi; first_lsa eklenmez.
                    start = td * SECTOR
                    nbytes = ns * SECTOR
                    if start >= size:
                        continue
                    if start + nbytes > size:
                        nbytes = size - start
                    f.seek(start)
                    left = nbytes
                    while left > 0:
                        b = f.read(min(1 << 24, left))
                        if not b:
                            break
                        o.write(b)
                        left -= len(b)
                    written += nbytes - left
            total_out += written
            log(f"  {name:<14} {written/1024**3:7.3f} GB  -> parts/{name}.img")
    log(f"  toplam: {total_out/1024**3:.3f} GB")
    return parts


def main():
    log(f"UPDATE.APP aciliyor: {APP}")
    size = os.path.getsize(APP)
    with open(APP, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)

        log("[1] super sparse image araniyor (LP metadata ile dogrulanarak)...")
        found = find_sparse(mm, size)
        if found is None:
            log("  HATA: super bulunamadi")
            return 1
        sp, sparse_end_off = found
        log(f"  secilen: 0x{sp:012x}")

        log("[2] super icindeki LP metadata konumu belirleniyor...")
        lp = find_lp(mm, sp, min(sparse_end_off + 0x100000, size))
        log(f"  sparse govdesi: 0x{sp:012x} - 0x{sparse_end_off:012x}")
        log(f"  LP metadata   : {('#0x%012x' % lp) if lp else 'BULUNAMADI'}")
        mm.close()

    raw_path = os.path.join(OUT, "super.raw")
    need_raw = not (os.path.exists(raw_path)
                    and os.path.getsize(raw_path) > 6.5 * 1024**3)
    if need_raw:
        log("\n[3] sparse -> raw cevriliyor...")
        with open(APP, "rb") as f:
            mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
            total = sparse_to_raw(mm, sp, raw_path)
            mm.close()
        log(f"  super.raw: {total/1024**3:.3f} GB")
    else:
        log("\n[3] super.raw zaten var, cevrim atlandi "
            f"({os.path.getsize(raw_path)/1024**3:.3f} GB)")

    log("\n[4] bolumler dilimleniyor...")
    lp_raw = find_lp_in_raw(raw_path)
    if lp_raw is None:
        log("  HATA: super.raw icinde gecerli LP metadata bulunamadi")
        return 1
    slice_partitions(raw_path, lp_raw)
    log("\nTamamlandi.")
    return 0


if __name__ == "__main__":
    sys.exit(main())