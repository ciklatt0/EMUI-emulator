#!/bin/bash
# system_server'ın cmdline'ı "--runtime-init" icerir.
# 200ms ile 20 sn yoklama.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote baslat + runtime-init arama ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zigtest >/dev/null 2>&1 &
   i=0; hit=0
   while [ $i -lt 100 ]; do
     if /bb/ps -A 2>/dev/null | /bb/grep -q "runtime-init"; then
       echo "BULUNDU (tur $i): $(/bb/ps -A 2>/dev/null | /bb/grep runtime-init | /bb/tr -s " ")"
       hit=1; break
     fi
     i=$((i+1)); /bb/sleep 0.2
   done
   [ $hit -eq 0 ] && echo "20 sn icinde runtime-init YOK"'