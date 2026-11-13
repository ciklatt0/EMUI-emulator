#!/bin/bash
# linker: libnativeloader.so not found -- needed by app_process64
# 1) kutuphane diskte NEREDE?
# 2) ld.config.txt (biz mountapex'te URETIYORUZ) ne diyor?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libnativeloader.so diskte nerede ==="
A 'find /system /vendor /apex -name "libnativeloader*" 2>/dev/null | head -10'
echo ""
echo "=== 2) app_process64 gercekten ne istiyor (readelf DT_NEEDED) ==="
A 'ls -l /system/lib64/libnativeloader* /system/lib64/nativeloader/ 2>&1 | head -8'
echo ""
echo "=== 3) ld.config.txt nerede ve kac satir ==="
A 'ls -l /system/etc/ld.config.txt /apex/com.android.runtime/etc/ld.config*.txt 2>&1 | head -5'
echo ""
echo "=== 4) ld.config.txt icinde nativeloader geciyor mu ==="
A 'grep -c nativeloader /system/etc/ld.config.txt 2>&1'
A 'grep -o "dir = .*lib64.*" /system/etc/ld.config.txt 2>&1 | head -8'
echo ""
echo "=== 5) adbd nasil basladi? (LD_LIBRARY_PATH env) ==="
A 'tr "\0" "\n" < /proc/$(pgrep adbd 2>/dev/null | head -1)/environ 2>/dev/null | grep -i "LD_\|PATH" | head -5'