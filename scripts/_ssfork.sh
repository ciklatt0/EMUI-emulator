#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote PID, durum (R/S/Z/T), surec sayisi ==="
A 'ps -A 2>/dev/null | grep zygote64 | head -4'
A 'for p in $(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f2); do echo "pid=$p state=$(cut -d" " -f3 /proc/$p/stat) ppid=$(cut -d" " -f4 /proc/$p/stat) threads=$(ls /proc/$p/task 2>/dev/null | wc -l)"; done'
echo ""
echo "=== 2) zygote logcat izleri (TUM buffer) ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "zygote|ZygoteInit|appproc" | tail -12'
echo ""
echo "=== 3) system_server hic gorundu mu ==="
A 'logcat -d -b all 2>/dev/null | grep -ciE "system_server|SystemServer"'
echo ""
echo "=== 4) zygote restart sayisi (init gercekten restart ediyor mu) ==="
A 'getprop init.svc.zygote; logcat -d 2>/dev/null | grep -c "Service .zygote"'
echo ""
echo "=== 5) /data/system ve zygote'un ihtiyac duydugu yollar ==="
A 'ls -ld /data/system /data/system/packages /data/dalvik-cache/arm64 2>&1 | head -4'