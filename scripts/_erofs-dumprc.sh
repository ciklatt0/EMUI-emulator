#!/bin/bash
# Firmware rc dosyalarini erofs imajindan diske dokup (analiz icin).
# Kullanim: _erofs-dumprc.sh <system.img> <cikti-dizini> <nid:ad> ...
set -u
IMG=$1; shift
OUT=$1; shift
mkdir -p "$OUT"
for spec in "$@"; do
  nid=${spec%%:*}
  ad=${spec#*:}
  dump.erofs --cat --nid="$nid" "$IMG" > "$OUT/$ad" 2>/dev/null
  printf '%-28s %s satir\n' "$ad" "$(wc -l < "$OUT/$ad")"
done