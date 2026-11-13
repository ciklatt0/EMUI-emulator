#!/bin/bash
# YENI BULGU: ANDROID_RUNTIME_ROOT ile zygote 14 sn yasadi
# (RC=124 = timeout oldu, kendi cikmadi). Onceki kosular
# RC=0 idi (1-3 sn).
# Simdi YASAYAN zygote'yi incele:
#   libart yuklendi mi, cocugu (system_server) var mi,
#   thread sayisi kacti.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) linker64 --list ile app_process64'in GERCEK kutuphane listesi ==="
A '/system/bin/linker64 --list /system/bin/app_process64 2>&1 | head -12'
echo ""
echo "=== 2) linker64 --list libart.so (bagimlilik cozumlemesi testi) ==="
A '/system/bin/linker64 --list /apex/com.android.art/lib64/libart.so 2>&1 | head -8; echo "RC=$?"'
echo ""
echo "=== 3) YASAYAN zygote: 12 sn boyunca izle ==="
A 'logcat -b all -c 2>/dev/null
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=c9 >/dev/null 2>&1 &
   ZP=$!
   for S in 2 4 6 8 10 12; do
     /bb/sleep 2
     if [ -d /proc/$ZP ]; then
       CH=""
       for d in /proc/[0-9]*; do
         pp=$(awk "{print \$4}" $d/stat 2>/dev/null)
         [ "$pp" = "$ZP" ] && CH="$CH $(basename $d)"
       done
       printf "  t=%-3s pid=%s libart=%-3s thr=%-3s cocuk=[%s]\n" "$S" "$ZP" "$(grep -c libart.so /proc/$ZP/maps)" "$(ls /proc/$ZP/task 2>/dev/null | wc -l)" "$CH"
     else
       echo "  t=$S OLDU"; break
     fi
   done
   kill -9 $ZP 2>/dev/null; wait $ZP 2>/dev/null
   echo "  RC=$?"
   echo "--- bu PIDe ait loglar:"
   logcat -d -b all 2>/dev/null | grep "( *$ZP)" | grep -v "avc:" | head -10'
echo ""
echo "=== 4) sistemde system_server var MI (tum yontemler) ==="
A 'for d in /proc/[0-9]*; do E=$(readlink $d/exe 2>/dev/null); case "$E" in *app_process*) echo "$(basename $d) -> $E  st=$(awk "{print \$3}" $d/stat)";; esac; done
   echo "--- init.svc:"; getprop init.svc.zygote'