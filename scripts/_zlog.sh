#!/bin/bash
# zygote 'exited with status 0' ile cikiyor (SIGABRT degil) ve init
# 'critical process exited 4 times' deyip vazgeciyor.
# Cikis ONCESI logcat'te ne yaziyor?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) logcat son 45 satir (raw) ==="
A 'logcat -d 2>/dev/null | grep -v "avc:" | tail -45'
echo ""
echo "=== 2) zygote/SystemServer'e ozel satirlar ==="
A 'logcat -d 2>/dev/null | grep -viE "avc:" | grep -iE "zygote|system_server|server|dalvik|art |Runtime|preload" | tail -20'