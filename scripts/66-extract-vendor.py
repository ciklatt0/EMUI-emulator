#!/usr/bin/env python3
"""
cust / preload paketlerindeki UPDATE.APP dosyalarini tara ve iclerindeki
DOSYA SISTEMI bloklarini cikarir.

Neden bu yol? super'ın LP metadata'sı vendor/odm'yi gosteriyor ama o
extent'ler super.raw'ta ISLENMEMIS BOLGEYE bakiyor (super.raw'a yalnizca
4.711 GB yazildi, vendor 5.7 GB'de). Bu iki ek paket (cust 387 MB,
preload 1.25 GB) muhtemelen eksik kalan bolumleri tasiyor.

LP metadata'ya ihtiyac yok: EROFS superblock'in kendisi dogrudan
bulunabilir. Dogrulama: magic + blkszbits(9..16) + blocks makul.
"""
import os, struct, zipfile, io

FW = "/root/harmony-build/fw-noh/Software/dload/NOH-AN00_cmcc_cn"
OUT = "/root/harmony-build/vendor-out"
os.makedirs(OUT, exist_ok=True)

PKGS = {
    "cust": f"{FW}/update_sd_cust_NOH-AN00_cmcc_cn.zip",
    "preload": f"{FW}/update_sd_preload_NOH-AN00_cmcc_cn_R11.zip",
}

EROFS_MAGIC = bytes.fromhex("e2e1f5e0")


def sb_info(buf, i):
    """i: EROFS magic konumu. -> (part_start, fs_size, blocks, blkszbits)"""
    if i < 1024:
        return None
    sb = i                      # superblock 1024. bayttan baslar
    if len(buf) < sb + 64:
        return None
    magic, csum, fcompat = struct.unpack_from("<III", buf, sb)
    if magic != 0xE0F5E1E0:
        return None
    blkszbits = buf[sb + 12]
    if not (9 <= blkszbits <= 16):
        return None
    blocks = struct.unpack_from("<I", buf, sb + 36)[0]
    if blocks == 0 or blocks > (1 << 24):
        return None
    return (sb - 1024, blocks * (1 << blkszbits), blocks, blkszbits)


def scan_blob(name, data):
    """Tek bir dosya govdesinde EROFS'leri bul."""
    hits = []
    pos = 0
    while True:
        i = data.find(EROFS_MAGIC, pos)
        if i == -1:
            break
        pos = i + 1
        r = sb_info(data, i)
        if r:
            hits.append(r)
    return hits


for pkg, zp in PKGS.items():
    print(f"\n===== {pkg}: {os.path.basename(zp)} =====")
    if not os.path.exists(zp):
        print("  dosya yok")
        continue
    with zipfile.ZipFile(zp) as z:
        for member in z.namelist():
            if not member.upper().endswith(".APP"):
                continue
            info = z.getinfo(member)
            print(f"  {member}: {info.file_size:,} bayt")
            data = z.read(member)
            print(f"  ilk bayt: {data[:16].hex(' ')}")

            # Android sparse mi?
            if data[:4] == struct.pack("<I", 0xED26FF3A):
                _m, _a, _b, fsz, csz, blk, blks, nch, _c = \
                    struct.unpack_from("<IHHHHIIII", data, 0)
                print(f"  -> Android sparse: blok={blk} bloklar={blks} "
                      f"({blks*blk/1024**3:.3f} GB) chunk={nch}")
            hits = scan_blob(member, data)
            print(f"  gecerli EROFS: {len(hits)}")
            for pstart, fssz, blocks, bits in hits:
                print(f"    ofs=0x{pstart:x}  {fssz/1024**3:.3f} GB  "
                      f"blok={blocks} blkszbits={bits}")
                dst = os.path.join(OUT, f"{pkg}_{member}_{pstart:010x}.img")
                with open(dst, "wb") as o:
                    o.write(data[pstart:pstart + fssz])
                print(f"      -> {os.path.basename(dst)} "
                      f"({os.path.getsize(dst):,} bayt)")
            del data

print(f"\ncikti: {OUT}")