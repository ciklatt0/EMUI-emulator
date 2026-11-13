#!/bin/bash
# "libart yuklenmiyor" bulgusu TEK ORNEKLE (t=1sn) alinmisti.
# TCG altinda bu cok erken olabilir. 0.2/0.5/1/2/3/5/8 sn'de
# ORNEKLEYEREK dogrulayalim. Disaridan da surecin yasamamasi
# icin arka planda baslatip PID'yi dogrulanmis sekilde izleyecegiz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== cok noktali ornek: libart gercekten yukleniyor mu ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zo1 >/dev/null 2>&1 &
   ZP=$!
   for MS in 200 500 1000 2000 3000 5000 8000 12000; do
     /bb/sleep 0.$((MS/100))
     if [ -d /proc/$ZP ]; then
       printf "  t=%-6s yasama=evet libart=%-3s libartbase=%-3s libnativebridge=%-3s thr=%-3s maps=%-4s\n" \
         "$MS" "$(grep -c libart.so /proc/$ZP/maps)" "$(grep -c libartbase /proc/$ZP/maps)" \
         "$(grep -c libnativebridge /proc/$ZP/maps)" "$(ls /proc/$ZP/task 2>/dev/null | wc -l)" "$(grep -c . /proc/$ZP/maps)"
     else
       printf "  t=%-6s OLDU\n" "$MS"
       break
     fi
   done
   kill -9 $ZP 2>/dev/null; wait $ZP 2>/dev/null' 2>&1
echo ""
echo "=== kontrol: dalvikvm64 gercekten libart yukluyor mu (maps) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /apex/com.android.art/bin/dalvikvm64 -cp /system/framework/core-libart.jar core.TestMain --help >/dev/null 2>&1 &
   D=$!; /bb/sleep 2
   if [ -d /proc/$D ]; then
     echo "  libart    = $(grep -c libart.so /proc/$D/maps)"
     echo "  libartbase= $(grep -c libartbase /proc/$D/maps)"
     echo "  toplam maps= $(grep -c . /proc/$D/maps)"
   else echo "  dalvikvm64 2 sn icinde bitti"; fi
   kill -9 $D 2>/dev/null'