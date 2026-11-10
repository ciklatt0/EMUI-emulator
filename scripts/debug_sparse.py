import struct, mmap

path = '/root/harmony-build/evr-payload/UPDATE.APP'
with open(path, 'rb') as f:
    mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    size = len(mm)

SPARSE_MAGIC = 0xED26FF3A
LP_MAGIC = 0x414C5030
HDR = '<IHHHHIIII'
pat = struct.pack('<I', SPARSE_MAGIC)

cands = []
off = 0
while len(cands) < 40:
    i = mm.find(pat, off)
    if i == -1:
        break
    off = i + 1
    try:
        _m, _ma, _mi, fsz, csz, blk, blks, ch, _cs = struct.unpack_from(HDR, mm, i)
    except Exception:
        continue
    if (fsz == 28 and csz == 12 and blk == 4096
            and blks * blk > 4 * 1024**3 and 0 < ch < 100000):
        _m2, _ma2, _mi2, fsz2, csz2, blk2, blks2, nchunks, _cs2 = struct.unpack_from(HDR, mm, i)
        pos2 = i + fsz2
        raw = 0
        for _ in range(nchunks):
            ctype, _r, cblk, ctotal = struct.unpack_from('<HHII', mm, pos2)
            if ctype == 0xCAC1:
                raw += cblk * blk2
            pos2 += ctotal
            if pos2 > size:
                break
        lp_magic_packed = struct.pack('<I', LP_MAGIC)
        end = min(i + 0x100000, size)
        p = i
        has_lp = False
        while True:
            lp = mm.find(lp_magic_packed, p, end)
            if lp == -1:
                break
            p = lp + 1
            try:
                (lm, maj, mnr, hsz3, _hc, tsz, _tc,
                 p_off, p_num, p_size, _e_off, _e_num, _e_size,
                 _g_off, _g_num, _g_size, _b_off, _b_num, _b_size) = \
                     struct.unpack_from('<IHH I32s I32s IIII IIII IIII', mm, lp)
                if maj == 10 and 1 <= p_num <= 32 and p_size == 52:
                    has_lp = True
                    break
            except:
                continue
        virt_gb = blks * blk / 1024**3
        cands.append((has_lp, virt_gb, raw, i, pos2))
        print(f'  aday @0x{i:012x} LP={"var" if has_lp else "yok ":<3} virt={virt_gb:.3f} GB RAW={raw/1024**3:.3f} GB')

cands.sort(key=lambda t: (t[0], t[1]), reverse=True)
if cands:
    best = cands[0]
    print(f'BEST: @0x{best[3]:012x} virt={best[1]:.3f} GB')
else:
    print('No candidates found!')

mm.close()
