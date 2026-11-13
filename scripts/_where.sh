#!/bin/bash
# arkstdlib / libartbased / pandastdlib disk imajinda VAR (her
# biri 2 eslesme) ama mount edilmis bolumlerde DEGIL.
# HANGI BOLUMDE? Bayt ofsetlerini alip bolum tablosuyla eslestirelim.
IMG=/root/harmony-build/boot/system-disk.img
echo "=== 1) bolum tablosu ==="
fdisk -l "$IMG" 2>/dev/null | sed -n '/Device.*Start/,/^$/p' | head -35
echo ""
echo "=== 2) bayt ofsetleri ==="
for S in arkstdlib libartbased pandastdlib; do
  OFF=$(grep -a -b -o "$S" "$IMG" 2>/dev/null | head -2 | cut -d: -f1 | tr '\n' ' ')
  echo "  $S : $OFF"
done