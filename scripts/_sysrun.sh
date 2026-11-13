#!/bin/bash
# KESIF: app_process64 her zaman com.android.internal.os.RuntimeInit
# calistiriyor. RuntimeInit, system_server'in giris noktasi.
# AOSP'de zygote system_server'i
#   --runtime-init <sinif> ile baslatir.
# O yolu elle deneyelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) logcat temizle ==="
A 'logcat -c 2>/dev/null; echo ok'
echo ""
echo "=== 1) system_server sinifi services.jar icinde MI ==="
A '/system/bin/toybox unzip -l /system/framework/services.jar 2>/dev/null | grep -c "classes" ; /system/bin/toybox strings /system/framework/services.jar 2>/dev/null | grep -m3 "com.android.server.SystemServer"'
echo ""
echo "=== 2) --runtime-init com.android.server.SystemServer ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   ANDROID_RUNTIME_ROOT=/apex/com.android.art
   timeout 25 /system/bin/app_process64 -Xzygote /system/bin \
     --runtime-init com.android.server.SystemServer 2>&1 | head -12
   echo "RC=$?"'
echo ""
echo "=== 3) sonuc: system_server process ==="
A 'ps -A 2>/dev/null | grep -iE "system_server|runtime-init" | grep -v "sh -c" | head -3; echo "(bos ise yok)"'
echo ""
echo "=== 4) logcat ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:|wificond|HiTrace" | tail -18'