#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
B=$(wc -l < "$F")
echo "log: $F ($B satir)"
python3 "$(dirname "$0")/_adb-probe.py"
echo ""
echo "=== probun URETtIGI yeni log satirlari ==="
sleep 3
tail -n +$((B + 1)) "$F" | sed 's/\[[^]]*\] //' | head -40