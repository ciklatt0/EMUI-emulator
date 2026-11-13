#!/bin/bash
# zygote her 6 sn'de bir olup 3 sn sonra temiz cikiyor.
# 1) init'in zygote hakkinda dedikleri (status + kac kez)
# 2) crash buffer
# 3) elle calistirip /proc uzerinden nerede oldugunu izleme
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) init zygote servis hakkinda ne diyor ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "zygote" | grep -v "avc:" | grep -vE "appproc|AndroidRuntime" | tail -12'
echo ""
echo "=== 2) crash buffer ==="
A 'logcat -d -b crash 2>/dev/null | tail -20; echo "(bos ise crash yok)"'
echo ""
echo "=== 3) tombstone / signal izleri ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "signal|segfault|abort|Fatal|ANR in" | grep -v "avc:" | tail -8'
echo ""
echo "=== 4) elle calistir, /proc ile izle (3 sn boyunca 200 ms) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   timeout 12 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zp1 &
   P=$!
   i=0
   while [ $i -lt 15 ]; do
     if [ -d /proc/$P ]; then
       echo "  t=$((i*2)) state=$(cut -d" " -f3 /proc/$P/stat 2>/dev/null) wchan=$(cat /proc/$P/wchan 2>/dev/null) libs=$(grep -c . /proc/$P/maps 2>/dev/null) art=$(grep -c libart /proc/$P/maps 2>/dev/null) thr=$(ls /proc/$P/task 2>/dev/null | wc -l)"
     else
       echo "  t=$((i*2)) OLDI"; break
     fi
     i=$((i+1)); /bb/sleep 0.2
   done
   wait $P; echo "RC=$?"'