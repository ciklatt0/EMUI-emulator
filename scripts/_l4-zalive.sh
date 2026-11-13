#!/bin/bash
# mkdir sonrasi zygote sessiz kaldi (= oldu). Ayakta mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote process ==="
A 'ps -A 2>/dev/null | grep -E "app_process" | head -5'
echo ""
echo "=== 2) zygote'nin durumu (yeni surec) ==="
A 'for p in $(pgrep app_process64 2>/dev/null); do echo "pid $p: $(cat /proc/$p/stat 2>/dev/null | cut -d" " -f3)"; done'
echo ""
echo "=== 3) system_server / activitymanager var mi ==="
A 'ps -A 2>/dev/null | grep -iE "system_server|servicemanager|surfaceflinger" | head -5'
echo ""
echo "=== 4) logcat: zygote/system_server ==="
A 'logcat -d 2>/dev/null | grep -iE "SystemServer|ActivityManager|zygote64_32|Fully booted" | tail -12'