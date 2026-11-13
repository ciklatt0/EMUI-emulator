#!/bin/bash
# zygote fork EDIYOR ve wchan=do_wait ile COCUGU BEKLIYOR.
# Onceki "system_server yok" olcumu YANLI S POSITIFTi
# (ps|grep runtime-init kendi sh -c satiriyla eslesiyordu).
# Bu kez zygote PID'sinden COCUKLARINI dogrudan okuyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote baslayinca tum surec agacini yaz (4 sn sonra) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   timeout 20 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zc1 &
   ZP=$!
   /bb/sleep 4
   echo "--- zygote PID=$ZP  wchan=$(cat /proc/$ZP/wchan 2>/dev/null)"
   echo "--- COCUKLAR (PPID=$ZP):"
   for d in /proc/[0-9]*; do
     p=$(basename $d)
     [ "$p" = "$ZP" ] && continue
     ppid=$(awk "{print \$4}" $d/stat 2>/dev/null)
     [ "$ppid" = "$ZP" ] || continue
     echo "  cocuk pid=$p state=$(awk "{print \$3}" $d/stat) wchan=$(cat $d/wchan 2>/dev/null)"
     echo "         cmdline=$(tr "\0" " " < $d/cmdline 2>/dev/null)"
     echo "         exe=$(ls -l $d/exe 2>/dev/null | sed "s/.*-> //")"
     echo "         thread=$(ls $d/task 2>/dev/null | wc -l)"
   done
   kill $ZP 2>/dev/null; wait $ZP 2>/dev/null; echo "bitti"'