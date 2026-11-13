#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote64 PID 14051/14058 durum (R/S/Z/T) ==="
A 'for p in 14051 14058; do echo "pid=$p state=$(cut -d" " -f3 /proc/$p/stat 2>/dev/null) ppid=$(cut -d" " -f4 /proc/$p/stat 2>/dev/null) threads=$(ls /proc/$p/task 2>/dev/null | wc -l)"; done'
echo ""
echo "=== 2) logd sag mi ==="
A 'getprop init.svc.logd; pidof logd'
echo ""
echo "=== 3) logcat -d bos mu, /dev/log var mi ==="
A 'ls -l /dev/log 2>&1; logcat -d 2>&1 | wc -l; logcat -d -b all 2>&1 | wc -l'
echo ""
echo "=== 4) zygote acik socketleri ==="
A 'ls -l /proc/14051/fd 2>&1 | head -12'
echo ""
echo "=== 5) init zygote restart sayaci / son olaylar ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -aE "zygote|system_server" "$F" | grep -av "avc:" | tail -8 | cut -c1-150