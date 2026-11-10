#!/usr/bin/env python3
"""
LIO-AN00: super.raw'daki bos vendor/odm alanlarini sparse2'den gelen EROFS'le doldurur.

super.raw (6.633 GB):
  vendor: 0xa4d000 sekt??r = 5.150 GB, 1.072 GB (sifir)
  odm:    0xc72000 sekt??r = 6.223 GB, 0.410 GB (sifir)

sparse2-raw.img'den cikan EROFS'ler:
  part0: 0.957 GB  -> vendor
  part1: 0.258 GB  -> odm
"""
import os, mmap, sys

SUP1 = '/root/harmony-build/lio-super-out/super.raw'
VENDOR_IMG = '/root/harmony-build/lio-super-out/parts3/part0_0149a00000.img'
ODM_IMG = '/root/harmony-build/lio-super-out/parts3/part1_018e400000.img'

# super.raw'taki ofsetler (LP metadata'dan)
VENDOR_OFFSET = 0xa4d000 * 512   # 5.150 GB
ODM_OFFSET = 0xc72000 * 512      # 6.223 GB


def main():
    vsz = os.path.getsize(VENDOR_IMG)
    osz = os.path.getsize(ODM_IMG)
    print('vendor EROFS: %.3f GB' % (vsz / 1024**3))
    print('odm EROFS: %.3f GB' % (osz / 1024**3))

    a = open(SUP1, 'r+b')
    mm1 = mmap.mmap(a.fileno(), 0)
    sup1_size = len(mm1)

    v_end = VENDOR_OFFSET + vsz
    o_end = ODM_OFFSET + osz
    if v_end > sup1_size:
        print('HATA: vendor EROFS super.raw\'i tasiyor')
        return 1
    if o_end > sup1_size:
        print('HATA: odm EROFS super.raw\'i tasiyor')
        return 1

    v_region = mm1[VENDOR_OFFSET:v_end]
    o_region = mm1[ODM_OFFSET:o_end]
    if v_region.count(0) != len(v_region):
        print('UYARI: vendor alani tamamen sifir degil, yazilmiyor')
    else:
        with open(VENDOR_IMG, 'rb') as f:
            vdata = f.read()
        mm1[VENDOR_OFFSET:v_end] = vdata
        print('vendor yazildi: 0x%x - 0x%x (%.3f GB)' % (VENDOR_OFFSET, v_end, vsz / 1024**3))

    if o_region.count(0) != len(o_region):
        print('UYARI: odm alani tamamen sifir degil, yazilmiyor')
    else:
        with open(ODM_IMG, 'rb') as f:
            odata = f.read()
        mm1[ODM_OFFSET:o_end] = odata
        print('odm yazildi: 0x%x - 0x%x (%.3f GB)' % (ODM_OFFSET, o_end, osz / 1024**3))

    a.flush()
    mm1.close()
    a.close()
    print('\nTamamlandi. super.raw guncellendi.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

