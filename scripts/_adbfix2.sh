#!/bin/bash
# adbd crash-loop (svc=restarting). Sebep?
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) init: adbd servisi ==="
grep -a "Service 'adbd'\|service 'adbd'" "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-160
echo ""
echo "=== 2) adbd'in kendi ciktisi (kmsg, AVC disi) ==="
grep -ai "adbd" "$F" | grep -vai "avc:" | tail -12 | sed 's/\[[^]]*\] //' | cut -c1-200
echo ""
echo "=== 3) /bb/nb dizini var mi (yedek buraya yaziliyor) ==="
grep -a "adbd-init.log\|/bb/nb" "$F" | tail -3 | sed 's/\[[^]]*\] //' | cut -c1-120
echo ""
echo "=== 4) data dizinleri kuruldu mu ==="
grep -a "data dizinleri kuruldu" "$F" | tail -2 | sed 's/\[[^]]*\] //' | cut -c1-120
echo ""
echo "=== 5) zygote ==="
grep -a "ctl.start zygote" "$F" | tail -2 | sed 's/\[[^]]*\] //' | cut -c1-120