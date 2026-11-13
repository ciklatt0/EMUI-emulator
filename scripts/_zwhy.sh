#!/bin/bash
# Elle calistirilunca zygote SAGLAM. Init baslatinca oluyor.
# Iki kanal var:
#   1) rclog her servise 'stdio_to_kmsg' ekliyor -> stderr seri LOGDA
#   2) tombstoned logcat'e 'Abort message' yaziyor
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) logcat: Abort message (GERCEK SEBEP) ==="
A 'logcat -d 2>/dev/null | grep -E "Abort message" | tail -6'
echo ""
echo "=== 2) logcat: zygote/app_process satirlari (son) ==="
A 'logcat -d 2>/dev/null | grep -iE "app_process64|zygote" | grep -v "avc:" | tail -12'
echo ""
echo "=== 3) SERI LOG: app_process64 ciktisi (stdio_to_kmsg) ==="
grep -a "app_process64\|Zygote\|zygote64" "$F" 2>/dev/null | grep -v "avc:" | tail -12 | cut -c1-180
echo ""
echo "=== 4) DISAGREE: init'in ortaminda ne var (env farki olabilir) ==="
echo "--- init'in verdigi ortam (rc'den):"
grep -nE "service zygote" -A 12 "$(dirname "$0")/81-boot-zygote.sh" 2>/dev/null | head -3