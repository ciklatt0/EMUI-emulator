#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) kullanilabilir araclar ==="
A 'ls /system/bin | grep -iE "^(readelf|file|xxd|objdump|nm)$" | head -6'
echo ""
echo "=== 2) toybox file ==="
A '/system/bin/toybox file /system/bin/mediaserver 2>&1 | head -2'
echo ""
echo "=== 3) toybox file (digerleri) ==="
A '/system/bin/toybox file /apex/com.android.i18n/lib64/libandroidicu.so /apex/com.android.i18n/lib/libandroidicu.so /system/bin/app_process32 /system/bin/app_process64 2>&1 | head -6'
echo ""
echo "=== 4) mediaserver 32-bit calistirilabilir mi (ELF machine) ==="
A '/system/bin/toybox file /system/bin/mediaserver /system/bin/surfaceflinger /system/bin/audioserver 2>&1 | head -5'
echo ""
echo "=== 5) bizim ekledigimiz lib dizinleri sirasi ==="
A 'grep -n "namespace.default.search.paths += /apex" /linkerconfig/ld.config.txt | head -8'