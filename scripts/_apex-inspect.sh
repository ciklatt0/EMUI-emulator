#!/bin/bash
# Bir APEX bolumunu (ext4) konukta cikartip icerigini listeler.
# DIKKAT: APEX'ler ham .apex degil, acilmis ext4 bolum imajlari olarak
# duruyor (konukta "EXT4-fs (vda6): mounted" gorunuyor).
set -u
N=${1:-6}
D=/root/harmony-build/boot/system-disk.img
case "$N" in
  6)  START=15532032; SZ=20479 ;;
  7)  START=15554560; SZ=4095  ;;
  26) START=15986688; SZ=94207 ;;
  *)  echo "bilinmeyen bolum"; exit 1 ;;
esac
OUT=/tmp/apexdev.img
dd if="$D" of="$OUT" bs=512 skip=$START count=$SZ status=none
echo "cikarildi: $OUT ($(stat -c%s "$OUT") bayt)"
mkdir -p /tmp/apexmnt
mount -o loop,ro "$OUT" /tmp/apexmnt 2>/dev/null || {
  echo "loop mount basarisiz; debugfs ile bakiliyor"
  debugfs -R "ls -l /" "$OUT" 2>/dev/null | head -20
  exit 1
}
echo "--- kok ---"
ls -la /tmp/apexmnt | head -20
echo "--- lib64 ---"
ls /tmp/apexmnt/lib64 2>/dev/null | head -30
echo "--- etc ---"
ls -la /tmp/apexmnt/etc 2>/dev/null | head -20
umount /tmp/apexmnt 2>/dev/null