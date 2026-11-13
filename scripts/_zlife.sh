#!/bin/bash
# zygote EXIT=0 ile cikiyor ve system_server hic fork etmiyor.
# 1) zygote ne kadar yasiyor? (sure)
# 2) fork ettigi an var mi? (cocuk PID'leri)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote omru + cocuk sayimi ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   T0=$(/bb/date +%s)
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zigtest >/dev/null 2>&1 &
   ZP=$!
   /bb/sleep 1
   echo "1 sn sonra zygote cocuklari: $(/bb/ls /proc/$ZP/task 2>/dev/null | wc -l) thread"
   wait $ZP; RC=$?
   T1=$(/bb/date +%s)
   echo "zygote $((T1-T0)) sn yasadi, cikis kodu=$RC"'
echo ""
echo "=== 2) system_server'in calismasi icin gerekenler ==="
A 'ls -l /system/framework/framework-res.apk /system/framework/services.jar /system/framework/framework.jar 2>&1 | head -4'
echo ""
echo "=== 3) servicemanager ayakta MI (zygote ona baglanir) ==="
A 'getprop init.svc.servicemanager; ps -A 2>/dev/null | grep -c servicemanager'
echo ""
echo "=== 4) zygote icin gerekli ORTAM (eller dene) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   timeout 12 /system/bin/app_process64 -Xzygote /system/bin --zygote 2>&1 | head -5; echo "RC=$?"'