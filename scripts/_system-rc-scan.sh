#!/bin/bash
# /system/etc/init altindaki rc dosyalarini ALT DIZINLERLE birlikte dokup
# 'subcontext' komutunu arar.
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=1048576
OUT=/tmp/system-rc
rm -rf "$OUT"; mkdir -p "$OUT"

walk() { # <nid> <yon>
  local nid=$1 yol=$2
  dump.erofs --offset=$OFF --ls --nid="$nid" "$D" 2>/dev/null > /tmp/_ls.txt
  while read -r cnid typ name; do
    [ -n "$cnid" ] || continue
    case "$typ" in
      1) dump.erofs --offset=$OFF --cat --nid="$cnid" "$D" 2>/dev/null \
           > "$OUT/${yol}_$name" 2>/dev/null ;;
      2|5) mkdir -p "$OUT/$yol"; walk "$cnid" "${yol}_${name}_" ;;
    esac
  done < <(awk 'NR>10 {print $1, $2, $3}' /tmp/_ls.txt)
}

walk 28974976 ""
echo "dokulen rc: $(find "$OUT" -type f | wc -l)"
echo ""
echo "=== 'subcontext' iceren dosyalar ==="
grep -rln 'subcontext' "$OUT" 2>/dev/null | sed "s#$OUT/##"
echo ""
echo "=== 'enter_default_mount_ns' ==="
grep -rn 'enter_default_mount_ns' "$OUT" 2>/dev/null | sed "s#$OUT/##" | head
echo ""
echo "=== 'apexd-bootstrap' ==="
grep -rn 'apexd-bootstrap' "$OUT" 2>/dev/null | sed "s#$OUT/##" | head