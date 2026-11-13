#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) /data mesajlari ==="
grep -a 'GERCEK BOLUM\|--- /data ---\|tmpfs baglandi\|zaten mountlu' "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-130
echo "  (bos = bu blok hic calismadi)"
echo ""
echo "=== 2) /init'in DATADEV mesaji ==="
grep -a '/data:' "$F" | head -5 | sed 's/\[[^]]*\] //' | cut -c1-130
echo ""
echo "=== 3) /init icinde DATASRC satiri VAR MI (uretilen init) ==="
grep -a 'DATASRC' "$F" | head -3 | cut -c1-100
echo "  (bos = uretilen /init'te bu blok yok)"
echo ""
echo "=== 3-bis) uretilen /init icinde DATAASRC olup olmadigi (dosyadan) ==="
R=$(grep -ao '### /data: gecici tmpfs' "$F" | head -1)
echo "  iz: [$R]"