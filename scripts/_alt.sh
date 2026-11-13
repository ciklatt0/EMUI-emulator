#!/bin/bash
# 1) app_process'in normal main akisi calisiyor mu?
#    (bilinmeyen sinif hatasi basmasi gerekir)
# 2) AOSP'nin BELGELENMIS alternatif zygote cagrisi:
#       app_process /system/bin com.android.internal.os.ZygoteInit
#    Bu, --zygote bayragindan farkli yoldur ve bazen calisir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) bilinmeyen sinif (main akisi kaniti) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 12 /system/bin/app_process64 /system/bin com.NoSuchClass 2>&1 | head -6; echo "RC=$?"'
echo ""
echo "=== 2) ALTERNATIF zygote cagrisi (AOSP dokumantasyonu) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   T0=$(/bb/date +%s)
   timeout 20 /system/bin/app_process64 /system/bin com.android.internal.os.ZygoteInit \
       --start-system-server --socket-name=zigalt 2>&1 | head -10
   RC=$?; T1=$(/bb/date +%s)
   echo "ALTERNATIV $((T1-T0))sn RC=$RC"'
echo ""
echo "=== 3) alternatif sonrasi system_server ==="
A 'ps -A 2>/dev/null | grep -iE "system_server|runtime-init" | grep -v "sh -c" | head -3'
echo ""
echo "=== 4) app_process64 gercekten kendi kodunu mi calistiriyor (objdump ile) ==="
A '/system/bin/toybox readelf -h /system/bin/app_process64 2>&1 | head -10'