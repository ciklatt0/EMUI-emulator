#!/bin/bash
# YANLI OLCUM DUZELTMESI:
# "&" ile arka planda baslatip $! aldigimizde PID, busybox
# "timeout"un PID'sidir; app_process64 onun COCUGUDUR. Bu yuzden
# wchan=do_wait gorduk (timeout cocugunu bekliyordu), zygote degil.
# BU SEFERD:
#   1) timeout KULLANMIYORUZ
#   2) $! gercekten app_process64 mu ARACla dogrulanir
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ARAC DOGRULAMASI: \$! gercekten app_process64 mu ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zv1 >/dev/null 2>&1 &
   ZP=$!
   echo "PID=$ZP cmdline=[$(tr "\0" " " < /proc/$ZP/cmdline 2>/dev/null)]"
   echo "exe=$(ls -l /proc/$ZP/exe 2>/dev/null | sed "s/.*-> //")"'
echo ""
echo "=== 2) GERCEK COCUK takibi (timeout'suz) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zv2 >/dev/null 2>&1 &
   ZP=$!
   i=0
   while [ $i -lt 14 ]; do
     if [ ! -d /proc/$ZP ]; then echo "  t=$((i)) zygote OLDI"; break; fi
     W=$(cat /proc/$ZP/wchan 2>/dev/null)
     CH=""
     for d in /proc/[0-9]*; do
       p=$(basename $d)
       [ "$p" = "$ZP" ] && continue
       pp=$(awk "{print \$4}" $d/stat 2>/dev/null)
       [ "$pp" = "$ZP" ] && CH="$CH $p"
     done
     echo "  t=$((i)) st=$(awk "{print \$3}" /proc/$ZP/stat) wchan=$W cocuk=[$CH] thr=$(ls /proc/$ZP/task 2>/dev/null | wc -l)"
     i=$((i+1)); /bb/sleep 1
   done
   for d in /proc/[0-9]*; do
     p=$(basename $d); pp=$(awk "{print \$4}" $d/stat 2>/dev/null)
     [ "$pp" = "$ZP" ] && { echo "  COCUK pid=$p"; echo "    cmd=[$(tr "\0" " " < $d/cmdline 2>/dev/null)]"; echo "    exe=$(ls -l $d/exe 2>/dev/null | sed "s/.*-> //")"; echo "    wchan=$(cat $d/wchan 2>/dev/null)"; echo "    thr=$(ls $d/task 2>/dev/null | wc -l)"; echo "    maps=$(grep -c . $d/maps 2>/dev/null)"; echo "    libart=$(grep -c libart $d/maps 2>/dev/null)"; }
   done
   kill -9 $ZP 2>/dev/null'