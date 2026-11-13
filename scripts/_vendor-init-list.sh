#!/bin/bash
# /vendor/etc/init dosyalarini alfabetik listeler ve belirtilen dosyayi basar.
# Kullanim: _vendor-init-list.sh <nid> [nid2 ...]
D=/root/harmony-build/boot/system-disk.img
OFF=$((11806720 * 512))
N=11935451
dump.erofs --offset=$OFF --ls --nid="$N" "$D" 2>/dev/null > /tmp/vendor-init.txt
echo "--- sirali liste ---"
awk 'NR>10 && $2==1 {print $3}' /tmp/vendor-init.txt | sort | nl | head -40
echo ""
for want in "$@"; do
  m=$(awk -v p="$want" 'NR>10 && $3==p {print $1; exit}' /tmp/vendor-init.txt)
  if [ -z "$m" ]; then echo "YOK: $want"; continue; fi
  echo "=========== $want (nid $m) ==========="
  dump.erofs --offset=$OFF --cat --nid="$m" "$D" 2>/dev/null
done