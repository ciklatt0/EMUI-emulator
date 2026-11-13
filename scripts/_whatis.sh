#!/bin/bash
# app_process64 argumansiz 3 sn sonra RC=0 ile cikiyor. Bu ikili
# gercekten Android'nin app_process'i mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) --help ciktisi (ANDROID_DATA ile) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 15 /system/bin/app_process64 --help 2>&1 | head -15'
echo ""
echo "=== 2) ikilideki 'usage' / zygote ile ilgili dizeler ==="
A 'strings /system/bin/app_process64 2>/dev/null | grep -iE "usage|zygote|runtime-init|nice name|classpath" | head -15'
echo ""
echo "=== 3) boyut ve karsilastirma ==="
A 'ls -l /system/bin/app_process64 /system/bin/app_process32 2>&1'
echo ""
echo "=== 4) libart'a baglanma denemesi (LD_DEBUG) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system LD_DEBUG=libs timeout 8 /system/bin/app_process64 2>&1 | grep -iE "libart|art\." | head -6'
echo ""
echo "=== 5) zygote icin gereken ZygoteInit sinifi framework icinde mi ==="
A 'ls /system/framework/framework.jar 2>&1; /system/bin/toybox strings /system/framework/framework.jar 2>/dev/null | grep -c "ZygoteInit"'
echo ""
echo "=== 6) persist.arkinit.disable=1 etkisi ==="
A 'getprop persist.arkinit.disable; getprop ro.ark.enable; getprop persist.sys.hw.forcedark_policy'