#!/bin/bash
# Firmware'in TUM bolumlerinde bir ozelligi arar (duzeltilmis surum).
# DIKKAT: ilk surum kok nid olarak 1 kullaniyordu; vendor/odm/cust
# bolumlerinde bu gecersiz ("bogus i_mode") ve o bolumler HIC taranmadi.
# Bu surum her bolumun gercek kok nid'ini superblogdan okuyor.
set -u
PROP=${1:-logsystem.usertype}
D=/root/harmony-build/boot/system-disk.img

scan() { # <offset> <etiket>
  local off=$1 tag=$2 rn
  rn=$(dump.erofs --offset=$off -s "$D" 2>/dev/null | awk '/root nid/{print $NF}')
  [ -n "$rn" ] || { echo "  /$tag: superblock okunamadi"; return 0; }
  echo "  /$tag kok nid=$rn"
  local n
  # kok ve /etc dizinindeki tum prop dosyalari
  for cand in build.prop default.prop prop.default; do
    n=$(dump.erofs --offset=$off --ls --nid=$rn "$D" 2>/dev/null | awk -v p="$cand" '$3==p{print $1; exit}')
    [ -n "$n" ] || continue
    if dump.erofs --offset=$off --cat --nid=$n "$D" 2>/dev/null | grep -q "$PROP"; then
      echo "BULUNDU: /$tag/$cand"
      dump.erofs --offset=$off --cat --nid=$n "$D" 2>/dev/null | grep -n "$PROP" | sed 's/^/    /'
    fi
  done
  local en
  en=$(dump.erofs --offset=$off --ls --nid=$rn "$D" 2>/dev/null | awk '$3=="etc"{print $1; exit}')
  [ -n "$en" ] && for cand in build.prop default.prop prop.default; do
    n=$(dump.erofs --offset=$off --ls --nid=$en "$D" 2>/dev/null | awk -v p="$cand" '$3==p{print $1; exit}')
    [ -n "$n" ] || continue
    if dump.erofs --offset=$off --cat --nid=$n "$D" 2>/dev/null | grep -q "$PROP"; then
      echo "BULUNDU: /$tag/etc/$cand"
      dump.erofs --offset=$off --cat --nid=$n "$D" 2>/dev/null | grep -n "$PROP" | sed 's/^/    /'
    fi
  done
  return 0
}

scan 1048576            system
scan $((7204864  * 512)) hw_product
scan $((11806720 * 512)) vendor
scan $((13907968 * 512)) odm
scan $((15308800 * 512)) cust
echo "arama bitti: $PROP"