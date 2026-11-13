#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== son 30 satir (AVC haric) ==="
grep -av "avc:" "$F" | tail -30 | sed 's/\[[^]]*\] //' | cut -c1-190
echo ""
echo "=== init mesajlari (son 12) ==="
grep -a "init:" "$F" | tail -12 | sed 's/\[[^]]*\] //' | cut -c1-190
echo ""
echo "=== son zaman damgasi ==="
grep -av "avc:" "$F" | tail -1 | cut -c1-40