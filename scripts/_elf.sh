#!/bin/bash
# Hata: libandroidicu.so 64-bit, istenen 32-bit.
# Kim 32-bit? mediaserver ELF sinifi ne?
# ELF header: offset 4 = EI_CLASS (1=32bit, 2=64bit)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ELF siniflari (1=32bit, 2=64bit) ==="
for f in /system/bin/mediaserver /system/bin/audioserver /system/bin/cameraserver \
         /system/bin/surfaceflinger /system/bin/app_process64 /system/bin/app_process32 \
         /apex/com.android.i18n/lib64/libandroidicu.so /apex/com.android.i18n/lib/libandroidicu.so \
         /apex/com.android.art/lib64/libnativeloader.so /apex/com.android.art/lib/libnativeloader.so ; do
  A "printf '%-52s ' $f; /bb/dd if=$f bs=1 skip=4 count=1 2>/dev/null | /bb/od -An -tu1 2>/dev/null | /bb/tr -d ' \n'; echo"
done
echo ""
echo "=== 2) mediaserver gercekten 32-bit mi ==="
A '/bb/readelf -h /system/bin/mediaserver 2>&1 | head -6'
echo ""
echo "=== 3) bizim 32/64 arama siramiz ==="
A 'grep -n "i18n" /linkerconfig/ld.config.txt | head -6'