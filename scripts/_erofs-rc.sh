#!/bin/bash
# rc dosyasini erofs imajindan cekip ilgili satirlari gosterir.
IMG=$1
shift
NID=$1
shift
OUT=/tmp/sysx/_rc.txt
dump.erofs --cat --nid="$NID" "$IMG" 2>/dev/null > "$OUT"
echo "satir: $(wc -l < "$OUT")"
grep -n -E "$@" "$OUT" | head -60