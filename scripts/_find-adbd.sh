#!/bin/bash
# /system/etc/init ve /vendor/etc/init icinde 'adbd' gecen satirlari
# bulur. adbd, Android framework'e BAGIMSIZ bir ikilidir; shell vermek
# icin zygote/SystemServer'a ihtiyac duymaz. Bu yuzden L5'e en kisa yol
# adbd'yi ayaga kaldirmak olabilir.
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=1048576
OUT=/tmp/sr
rm -rf "$OUT"; mkdir -p "$OUT"

walk() {
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
echo "rc dosyasi: $(find "$OUT" -type f | wc -l)"
echo ""
echo "=== 'service adbd' tanimi ==="
grep -rn -A10 'service adbd' "$OUT" 2>/dev/null | sed "s#$OUT/##"
echo ""
echo "=== 'start adbd' / adbd tetikleyicileri ==="
grep -rn 'adbd' "$OUT" 2>/dev/null | sed "s#$OUT/##" | head -20