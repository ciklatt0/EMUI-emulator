#!/bin/bash
# zygote ZOMBIE. Sebebini elle calistirip logcat'ten aliyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) logcat temizle ==="
A 'logcat -c 2>/dev/null; echo ok'
echo ""
echo "=== 1) zygote'u ELLE, --start-system-server ile baslat ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   ANDROID_RUNTIME_ROOT=/apex/com.android.art
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zygotemanual \
     > /dev/null 2>&1 &
   echo "baslatildi"'
sleep 20
echo ""
echo "=== 2) Bu 20 saniyede zygote ne yazdi ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | tail -30'