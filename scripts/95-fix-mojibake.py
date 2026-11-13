#!/usr/bin/env python3
"""Mojibake (cift/kosulu kodlamali UTF-8) satirlarini duzeltir.

NEDEN
-----
PowerShell'in 'Set-Content -Encoding UTF8' komutu dosyayi BOM + CRLF ile
yazarken, dosyada zaten UTF-8 olan Turkce karakterleri Latin-1 gibi
yorumlayip iki kez kodlar:

    'ş' = U+015F = C5 9F   ->   'Å' + U+009F   ->   C3 85 C2 9F

Dosya birkac kez PowerShell'dan gectigi icin bazi satirlar 3-4 KEZ
kodlanmis olabiliyor. Tek gecis yetmiyor; sabit noktaya kadar
cozmek gerekiyor.

NEDEN SADECE YORUM
------------------
Bozulan yerler hep yorum satirlari. Kod calisiyor; dosya yalnizca
okunmaz hale geliyor. Yine de biriktigi icin temizleniyor -- bir sonraki
duzenlemede hatayi gormeyi engelliyor.

ALGILAMA
--------
Mojibake, Turkce metinde OLMAYAN bir byte izi birakir: C2 80..C2 BF.
Cift kodlamali her Turkce harf Latin-1 karsiliginin U+0080..U+00BF
araligina dustugu icin C2 ile baslayan bir cift uretir. Dogru kodlanmis
metinde boyle bir iz BULUNMAZ.
"""
import re
import sys

MOJI = re.compile(rb'\xc2[\x80-\xbf]')
MAX_ROUNDS = 6


def fix_line(line: bytes) -> bytes:
    for _ in range(MAX_ROUNDS):
        if not MOJI.search(line):
            break
        try:
            s = line.decode('utf-8')
            s = s.encode('latin-1', 'strict').decode('utf-8', 'strict')
            line = s.encode('utf-8')
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
    return line


def main(paths):
    rc = 0
    for p in paths:
        try:
            raw = open(p, 'rb').read()
        except OSError as e:
            print(f'  [HATA] {p}: {e}')
            rc = 1
            continue
        lines = raw.split(b'\n')
        bad = [i for i, l in enumerate(lines) if MOJI.search(l)]
        if not bad:
            print(f'  [temiz] {p}')
            continue
        for i in bad:
            lines[i] = fix_line(lines[i])
        open(p, 'wb').write(b'\n'.join(lines))
        left = sum(1 for l in lines if MOJI.search(l))
        print(f'  [ok] {p}: {len(bad)} satir tarandi, kalan {left}')
        if left:
            rc = 1
    return rc


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]) or 0)