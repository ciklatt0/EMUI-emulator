#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) app_process64 tam hata mesaji ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK EXECUTABLE \"/system/bin/app_process64\"" | head -3'
echo ""
echo "=== 2) logcat'teki tum app_process64 satirlari (AVC disi) ==="
A 'logcat -d -b all 2>/dev/null | grep -i "app_process64" | grep -v "avc:" | tail -12'
echo ""
echo "=== 3) zygote omru ve RC ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   T0=$(/bb/date +%s); timeout 15 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zt >/dev/null 2>&1; RC=$?; T1=$(/bb/date +%s)
   echo "zygote $((T1-T0))sn RC=$RC"'
echo ""
echo "=== 4) elle calistir (cikti acik) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 15 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zt2 2>&1 | head -10; echo "RC=$?"'