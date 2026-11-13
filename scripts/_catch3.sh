#!/bin/bash
# DIKKAT: onceki denemede YANLIS POZITIF olustu; "runtime-init"
# kelimesi arayan grep, kendi sh -c komut satirinda da geciyordu.
# Bu yuzden once /system/bin/sh ve grep'i eliyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote baslat + system_server yoklamasi (filtreli) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zigtest >/dev/null 2>&1 &
   i=0; hit=0
   while [ $i -lt 100 ]; do
     L=$(/bb/ps -A 2>/dev/null | /bb/grep runtime-init \
         | /bb/grep -v "sh -c" | /bb/grep -v "/bb/grep" | /bb/tr -s " ")
     if [ -n "$L" ]; then echo "BULUNDU tur=$i : $L"; hit=1; break; fi
     i=$((i+1)); /bb/sleep 0.2
   done
   [ $hit -eq 0 ] && echo "20sn icinde system_server YOK"'
echo ""
echo "=== 2) zygote bittikten sonra logcat (son 12) ==="
sleep 8
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:|wificond|HiTrace" | tail -12'