#!/bin/bash
# HIPOTEZ: ZygoteInit::start() ilk satirda
#     if (gZygoteHooks == nullptr) return;
# yapiyor. gZygoteHooks'i libzygote.so doldurur. Hook'lar
# gelmezse start() HICBIR HATA BASMADAN doner ve surec RC=0 ile
# cikar -- TAM DA OLCULEN DAVRANIS.
# Olcum: calisirken /proc/PID/maps icinde libzygote.so var MI.
# NOT: cikti once dosyaya yazilir, sonra okunur (adb oturumu
# arka plandaki surece bagli kalmasin).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libzygote.so diskte NEREDE ==="
A 'find /system /apex -name "libzygote.so" 2>/dev/null
   echo "--- boyut:"
   ls -l /apex/com.android.art/lib64/libzygote.so /system/lib64/libzygote.so 2>&1 | head -3'
echo ""
echo "=== 2) config [system] search.paths icinde art/lib64 var MI ==="
A 'grep -o "/apex/com.android.art/lib64" /linkerconfig/ld.config.txt | wc -l'
echo ""
echo "=== 3) calisirken maps (dosyaya yaz, sonra oku) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zm2 >/dev/null 2>&1 &
   ZP=$!
   /bb/sleep 1
   { if [ -d /proc/$ZP ]; then
       echo "  PID $ZP yasiyor (1 sn sonra)"
       echo "  libzygote       : $(grep -c libzygote /proc/$ZP/maps)"
       echo "  libart          : $(grep -c libart /proc/$ZP/maps)"
       echo "  libnativeloader : $(grep -c libnativeloader /proc/$ZP/maps)"
       echo "  thread          : $(ls /proc/$ZP/task 2>/dev/null | wc -l)"
       grep -oE "/[a-zA-Z0-9./]*(libzygote|libart|libnativeloader)[a-zA-Z0-9]*\.so" /proc/$ZP/maps 2>/dev/null | sort -u | sed "s/^/    /"
     else
       echo "  PID $ZP 1 sn icinde OLDI"
     fi; } > /tmp/zm.txt 2>&1
   wait $ZP 2>/dev/null
   echo "  RC=$?" >> /tmp/zm.txt
   cat /tmp/zm.txt'