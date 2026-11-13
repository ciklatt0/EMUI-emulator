#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F ($(wc -l < "$F") satir)"
echo ""
echo "=== 1) adbd izleri ==="
grep -a "adbd" "$F" | grep -av "avc:" | tail -10 | sed 's/\[[^]]*\] //' | cut -c1-200
echo ""
echo "=== 2) init adbd servisi ==="
grep -aE "Service 'adbd'|starting service 'adbd'|adbd=ayakta|ctl.start adbd" "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-160
echo ""
echo "=== 3) data dizinleri ==="
grep -a "data dizinleri kuruldu" "$F" | tail -2 | sed 's/\[[^]]*\] //' | cut -c1-120
echo ""
echo "=== 4) linker / CANNOT LINK ==="
grep -aE "CANNOT LINK|undefined namespace|config anahtar kontrolu|yamalandi: search" "$F" | tail -5 | sed 's/\[[^]]*\] //' | cut -c1-160
echo ""
echo "=== 5) zygote ==="
grep -aE "starting service 'zygote'|ctl.start zygote" "$F" | tail -3 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 6) nabiz (yasan surecler) ==="
grep -a "### nabiz" "$F" | tail -1 | sed 's/\[[^]]*\] //' | cut -c1-400