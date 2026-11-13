#!/bin/bash
S="$(dirname "$0")/81-boot-zygote.sh"
echo "=== uretilen dosya sinirlari (ROOT/... yazma isaretleri) ==="
grep -n 'ROOT/init\|ROOT/bb/\|^\$ROOT' "$S" | head -25
echo ""
echo "=== 'mkdir -p /data /data/local /data/system' hangi bolumde ==="
grep -n 'mkdir -p /data /data/local /data/system' "$S"
echo ""
echo "=== bu satirdan onceki en yakin dosya basligi ==="
awk 'NR<=3258 && (/ROOT\/[a-z]/ || /heredoc|BASLA|BITIR|^# ===|^# ---/) {n=NR; l=$0} END{}' "$S" | tail -1
echo "--- 3200-3260 arasi dosya isaretleri:"
sed -n '3150,3260p' "$S" | grep -n 'ROOT/\|=====' | head -10