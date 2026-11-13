#!/bin/bash
# zygote basliyor (START ZygoteInit) ve saniyeler icinde oluyor.
# On planda calistirip CIKIS KODUNU ve stddogrudun alalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) logcat temizle ==="
A 'logcat -c 2>/dev/null; echo ok'
echo ""
echo "=== 1) zygote on planda + cikis kodu (en fazla 25 sn) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   ANDROID_RUNTIME_ROOT=/apex/com.android.art
   timeout 25 /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zigtest 2>&1 | head -20
   echo "EXIT=$?"'
echo ""
echo "=== 2) o 25 saniyede zygote/ART ne yazdi ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | tail -25'