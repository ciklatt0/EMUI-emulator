#!/bin/bash
# IPv6 gomulu kernel + FD testi
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F ($(wc -l < "$F") satir)"
echo ""
echo "=== IPv6 calisiyor mu? ==="
grep -n 'netstat6\|IPv6' "$F" | sed 's/\[[^]]*\] //' | tail -3 | cut -c1-200
grep -n '###   net: \[' "$F" | sed 's/\[[^]]*\] //' | tail -1 | cut -c1-220
echo ""
echo "=== FD testi (KESIN) ==="
grep -n '### FD-adbd' "$F" | sed 's/\[[^]]*\] //' | cut -c1-400
echo ""
echo "=== AUTOPSY / svc ==="
grep -n 'AUTOPSY: adbd\|AUTOPSY tcp5555\|ctl.start adbd #' "$F" \
  | sed 's/\[[^]]*\] //' | tail -4 | cut -c1-180