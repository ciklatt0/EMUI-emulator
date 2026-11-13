#!/bin/bash
# app_process64 --help 0 bayt uretip RC=0 ile cikiyor (normal AOSP
# kullanim metni basar ve RC=1 verir).
# Huawei OZELLIKLERI: ro.ark.enable=1, persist.sys.hw.forcedark_policy=1,
# persist.arkinit.disable=1. "ro." salt-okunur ama "persist."
# degistirilebilir. Tek degiskenli deney yapalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ONCE: ozellikleri yazdir ==="
A 'getprop ro.ark.enable; getprop persist.sys.hw.forcedark_policy; getprop persist.arkinit.disable'
echo ""
echo "=== 2) persist degerlerini kapat ==="
A 'setprop persist.sys.hw.forcedark_policy 0; setprop persist.arkinit.disable 0; setprop ark.restart.status 0; sleep 2
getprop persist.sys.hw.forcedark_policy; getprop persist.arkinit.disable'
echo ""
echo "=== 3) app_process64 --help TEKRAR ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 12 /system/bin/app_process64 --help; echo "RC=$?"'
echo ""
echo "=== 4) zygote TEKRAR (omur + RC) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   T0=$(/bb/date +%s); timeout 12 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=t9 >/dev/null 2>&1; RC=$?; T1=$(/bb/date +%s)
   echo "zygote $((T1-T0))sn RC=$RC"'
echo ""
echo "=== 5) system_server var mi ==="
sleep 3
A 'ps -A 2>/dev/null | grep -iE "system_server|runtime-init" | grep -v "sh -c" | head -3; echo "(bos ise yok)"'