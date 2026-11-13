#!/bin/bash
# zygote EXIT=0 ile temiz cikiyor; system_server HIC gorunmuyor.
# Demek ki zygote onu fork edip coktugu anda kayboluyor olabilir.
# 200 ms ile yoklama yapip KISA OMURLU sureci yakalayalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote baslat + 15 sn 200ms aralikla surec listesi ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zigtest >/dev/null 2>&1 &
   i=0
   while [ $i -lt 75 ]; do
     /bb/ps -A 2>/dev/null | /bb/grep -viE "sh -c|grep|^USER|zygote64" | \
       /bb/awk "{print \$5, \$9}" | /bb/sort -u | /bb/tr "\n" " "
     echo ""
     i=$((i+1)); /bb/sleep 0.2
   done' 2>&1 | uniq | head -30