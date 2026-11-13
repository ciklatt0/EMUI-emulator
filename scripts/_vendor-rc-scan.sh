#!/bin/bash
# /vendor/etc/init altindaki TUM rc dosyalarini diske dokup, alt baglami
# oldurebilecek yapi turlarini tarar.
# DIKKAT: init alt baglami "/vendor/etc/init" dizinini tarayarak parse
# ediyor ve bir hatada CIKIYOR. Bu tarama hangi dosyanin supheli oldugunu
# onceden gormek icin.
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=$((11806720 * 512))
N=11935451
OUT=/tmp/vendor-rc
rm -rf "$OUT"; mkdir -p "$OUT"

dump.erofs --offset=$OFF --ls --nid="$N" "$D" 2>/dev/null > /tmp/vendor-init.txt
i=0
while read -r nid name; do
  i=$((i+1))
  dump.erofs --offset=$OFF --cat --nid="$nid" "$D" 2>/dev/null > "$OUT/$(printf '%03d' $i)_$name"
done < <(awk 'NR>10 && $2==1 {print $1, $3}' /tmp/vendor-init.txt | sort -k2)

echo "dokulen dosya: $i"
echo ""
echo "=== 'import' icerenler (alt baglamda cozulemezse hata verir) ==="
grep -ln '^[[:space:]]*import ' "$OUT"/* 2>/dev/null | head -20
echo ""
echo "=== 'subcontext' icerenler ==="
grep -ln 'subcontext' "$OUT"/* 2>/dev/null | head
echo ""
echo "=== 'on ' ile baslayan blok sayisi (her dosyada) ==="
for f in "$OUT"/*; do
  n=$(grep -c '^[[:space:]]*on ' "$f" 2>/dev/null)
  s=$(grep -c '^[[:space:]]*service ' "$f" 2>/dev/null)
  printf '%-62s on=%-3s service=%s\n' "$(basename "$f")" "$n" "$s"
done | head -60
echo ""
echo "=== onek disi service/on tanimlari (indent hatası olabilir) ==="
grep -ln '^service \|^on ' "$OUT"/* 2>/dev/null | head -10