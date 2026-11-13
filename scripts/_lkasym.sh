#!/bin/bash
# Daha once gordugumuz mesaji sitematik inceleyelim:
#   $ linker64 --list /apex/com.android.art/lib64/libart.so
#     CANNOT LINK: library "libartpalette.so" not found
#   $ linker64 --list /apex/com.android.art/lib64/libartpalette.so
#     TAMAM (liblog, libc++, libc cozuldu)
# Bu ASIMETRI nedir? Ayni dizindeki iki kutuphane, farkli sonuc.
# Hipotez: linker PROGRAMIN YOLUNDAN namespace seciyor ve
# /apex/com.android.art/ icin "com_android_art" bolumunu
# KULLANMIYOR (default'a dusuyor).
# Her APEX'ten bir kutuphane deneyip kaliabi gosterelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) art dizinindeki kutuphaneler tek tek ==="
A 'for L in libartpalette.so libartbase.so libprofile.so libdexfile.so libart.so; do
   P=/apex/com.android.art/lib64/$L
   [ -f "$P" ] || { echo "  $L: dosya yok"; continue; }
   R=$(/system/bin/linker64 --list "$P" 2>&1 | grep -c "CANNOT LINK")
   N=$(/system/bin/linker64 --list "$P" 2>&1 | grep -c "=>")
   echo "  $L: cozulen=$N  hata=$R"
 done'
echo ""
echo "=== 2) baska APEXlerden kontrol (ornek) ==="
A 'for P in /apex/com.android.i18n/lib64/libicu.so \
          /apex/com.android.runtime/lib64/bionic/libc.so \
          /system/lib64/liblog.so ; do
   [ -f "$P" ] || { echo "  $P yok"; continue; }
   R=$(/system/bin/linker64 --list "$P" 2>&1 | grep -c "CANNOT LINK")
   echo "  $P -> hata=$R"
 done'
echo ""
echo "=== 3) libart.so icin TAM hata mesajlari (hepsi) ==="
A '/system/bin/linker64 --list /apex/com.android.art/lib64/libart.so 2>&1 | head -10'
echo ""
echo "=== 4) libart.so DT_NEEDED sirasi (ilk 3) ==="
A '/system/bin/toybox readelf -d /apex/com.android.art/lib64/libart.so 2>/dev/null | grep NEEDED | head -3'