#!/bin/bash
# /vendor/etc/init/connectivity dizinini dokup, import yolunun hangi
# degerle cozulebilecegini gosterir.
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=$((11806720 * 512))
N=11935451
dump.erofs --offset=$OFF --ls --nid="$N" "$D" 2>/dev/null > /tmp/vendor-init.txt

echo "=== /vendor/etc/init alt dizinleri (tip 2 ve ustu) ==="
awk 'NR>10 && $2==2 {print $1, $3}' /tmp/vendor-init.txt | sort -k2

echo ""
echo "=== connectivity dizini icerigi ==="
CID=$(awk 'NR>10 && $3=="connectivity" {print $1; exit}' /tmp/vendor-init.txt)
echo "connectivity nid: $CID"
if [ -n "$CID" ]; then
  dump.erofs --offset=$OFF --ls --nid="$CID" "$D" 2>/dev/null | sed -n '10,40p'
fi

echo ""
echo "=== chiptype ozelligi firmware'da tanimli mi? ==="
for off in 1048576 $((7204864*512)) $OFF $((13907968*512)) $((15308800*512)); do
  case $off in
    1048576) tag=system ;;
    3628891648) tag=hw_product ;;
    6045040640) tag=vendor ;;
    7116883456) tag=odm ;;
    7838105600) tag=cust ;;
  esac
  rn=$(dump.erofs --offset=$off -s "$D" 2>/dev/null | awk '/root nid/{print $NF}')
  [ -n "$rn" ] || continue
  for f in build.prop default.prop; do
    bn=$(dump.erofs --offset=$off --ls --nid=$rn "$D" 2>/dev/null | awk -v p="$f" '$3==p{print $1; exit}')
    [ -n "$bn" ] || continue
    if dump.erofs --offset=$off --cat --nid=$bn "$D" 2>/dev/null | grep -q 'chiptype'; then
      echo "BULUNDU: /$tag/$f"
      dump.erofs --offset=$off --cat --nid=$bn "$D" 2>/dev/null | grep -n 'chiptype' | sed 's/^/    /'
    fi
  done
done
echo "arama bitti"