#!/bin/bash
# adb offline. ensure_zygote / data dizinleri izleri var mi?
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F ($(wc -l < "$F") satir)"
echo ""
echo "=== ensure_zygote / data dizinleri ==="
grep -E "ctl.start zygote|data dizinleri|zygote sureci|zzaten ayakta" "$F" | tail -8
echo ""
echo "=== adbd izleri ==="
grep -E "adbd" "$F" | tail -8
echo ""
echo "=== ld.config ==="
grep -E "ld.config.txt yamalan" "$F" | tail -3
echo ""
echo "=== son 15 satir ==="
tail -15 "$F" | sed 's/\[[^]]*\] //' | cut -c1-160