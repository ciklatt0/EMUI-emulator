#!/bin/bash
# erofs imajindan tek dosya cekip strings ile tarar.
# Kullanim: _erofs-strings.sh <img> [--offset=N] <nid> [grep-deseni]
# NOT: --offset ile disk imajinin bolumunu dogrudan okuyabilirsin;
# 3.4 GB kopyalama gerekmez. system bolumu icin:
#     dump.erofs --offset=1048576 ... (2048 sektor * 512)
set -u
IMG=$1; shift
OFF=""
if [ "${1:-}" = "--offset=1048576" ]; then OFF="--offset=1048576"; shift; fi
NID=$1; shift
PAT=${1:-.}
OUT=/tmp/_f.bin
dump.erofs $OFF --cat --nid="$NID" "$IMG" > "$OUT" 2>/dev/null
echo "boyut: $(stat -c%s "$OUT")  ($OUT)"
strings -a "$OUT" | grep -E "$PAT" | head -50