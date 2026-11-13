#!/bin/bash
# Bir dosyayi LF -> CRLF cevirir (kodlama DOKUNULMAZ).
# DIKKAT: 94-fix-crlf.sh yalnizca SHELL betikleri icindir; .cmd dosyasini
# bash -n ile ayristirmaya calisir ve hata verir.
set -u
for f in "$@"; do
  [ -f "$f" ] || continue
  if grep -q $'\r' "$f"; then
    echo "  [ok] $f  (zaten CRLF)"
  else
    sed -i 's/$/\r/' "$f"
    echo "  [ok] $f  LF -> CRLF"
  fi
done