#!/bin/bash
# adbd ayakta degil. Log uzerinden gidelim.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) ld.config durumu (kac kez yamalandi / kayboldu) ==="
grep -aE "ld.config.txt yamalan|KAYBOLMUS|apex/etc dizinine|SIFIRLADI" "$F" | tail -8 | sed 's/\[[^]]*\] //' | cut -c1-120
echo ""
echo "=== 2) adbd izleri ==="
grep -aE "adbd|ctl.start adbd|DGN global adbd" "$F" | tail -8 | sed 's/\[[^]]*\] //' | cut -c1-150
echo ""
echo "=== 3) nabiz satiri (hangi surecler yasiyor) ==="
grep -a "### nabiz" "$F" | tail -1 | sed 's/\[[^]]*\] //' | cut -c1-400
echo ""
echo "=== 4) CANNOT LINK (kernel logda) ==="
grep -a "CANNOT LINK" "$F" | tail -5 | sed 's/\[[^]]*\] //' | cut -c1-150
echo ""
echo "=== 5) son 8 satir ==="
tail -8 "$F" | sed 's/\[[^]]*\] //' | cut -c1-150