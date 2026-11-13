#!/bin/bash
S="$(dirname "$0")/81-boot-zygote.sh"
echo "--- 769. satir (supervise heredoc baslangici) ---"
sed -n '769p' "$S"
echo ""
echo "--- heredoc baslangic satirlari ---"
grep -n "<<'" "$S"
echo ""
echo "--- supervise icindeki \$ kacis sayisi ---"
sed -n '769,1457p' "$S" | grep -c '\\\$'
echo ""
echo "--- supervise icinde ornek: bir \$degisken kullanimi ---"
sed -n '795,800p' "$S"
echo ""
echo "--- uretilen supervise: \$CFG nasil gorunuyor ---"
grep -n 'CFG=' /root/harmony-build/initramfs-boot/bb/supervise | head -3