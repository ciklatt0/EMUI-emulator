#!/bin/bash
# /vendor/etc/init listesinin TAMAMINI yazar ve 'subcontext' iceren dosyalari arar.
D=/root/harmony-build/boot/system-disk.img
OFF=$((11806720 * 512))
N=11935451
dump.erofs --offset=$OFF --ls --nid="$N" "$D" 2>/dev/null > /tmp/vendor-init.txt
awk 'NR>10 && $2==1 {print $1, $3}' /tmp/vendor-init.txt | sort -k2 > /tmp/vendor-init-sorted.txt
echo "toplam rc dosyasi: $(wc -l < /tmp/vendor-init-sorted.txt)"
echo "--- 40-90 ---"
sed -n '40,95p' /tmp/vendor-init-sorted.txt
echo "--- 'subcontext' iceren dosyalar ---"
while read -r nid name; do
  if dump.erofs --offset=$OFF --cat --nid="$nid" "$D" 2>/dev/null | grep -q 'subcontext'; then
    echo "BULUNDU: $name (nid $nid)"
    dump.erofs --offset=$OFF --cat --nid="$nid" "$D" 2>/dev/null | grep -n 'subcontext' | sed 's/^/    /'
  fi
done < /tmp/vendor-init-sorted.txt
echo "arama bitti"