#!/bin/bash
# /vendor offset dogru ama --ls 0 dosya donuyor. Vendor gercekten
# erofs mu? Yoksa ext4 mi? Magic'e bak.
set -u
D=/root/harmony-build/boot/system-disk.img
for p in 1 2 3 4 5; do
  START=$(sgdisk -p "$D" 2>/dev/null | awk -v P=$p '$1==P{print $2}')
  OFF=$((START*512))
  NAME=$(sgdisk -p "$D" 2>/dev/null | awk -v P=$p '$1==P{print $NF}')
  MAGIC=$(dd if="$D" bs=1 skip=$((OFF+1024)) count=4 2>/dev/null | xxd -p)
  printf "  parca %-2s %-12s ofset=%-12s magic(1024)=%s\n" "$p" "$NAME" "$OFF" "$MAGIC"
done
echo ""
echo "erofs superblock magic = e2f50112 (little endian: 1201f5e2)"
echo ""
echo "=== vendor icinde /etc/init denemesi ==="
dump.erofs --offset=$((11806720*512)) --ls --path=/etc/init "$D" 2>&1 | head -8
echo ""
echo "=== vendor kok dizini ==="
dump.erofs --offset=$((11806720*512)) --ls "$D" 2>&1 | head -12