#!/bin/bash
# adbd'nin DT_NEEDED listesinde iki kutuphane var ki APEX payload'inda YOK:
#   libadbd_fs.so, libadbd_auth.so
# Firmware'in geri kalaninda var mi?  Varsa nereden?
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=1048576

echo "--- /system/lib64 icinde libadbd* / liblog / libselinux ---"
dump.erofs --offset=$OFF --ls --path=/system/lib64 "$D" 2>/dev/null | grep -iE 'adbd|liblog|libselinux' || echo "  (liste bos/hata)"

echo ""
echo "--- /system/bin icinde adbd ---"
dump.erofs --offset=$OFF --ls --path=/system/bin "$D" 2>/dev/null | grep -i 'adbd' || echo "  (/system/bin/adbd yok)"

echo ""
echo "--- /vendor/bin ve /vendor/lib64 ---"
VOFF=$((11806720*512))
dump.erofs --offset=$VOFF --ls --path=/vendor/bin "$D" 2>/dev/null | grep -i 'adbd' || echo "  (vendor/bin/adbd yok)"
dump.erofs --offset=$VOFF --ls --path=/vendor/lib64 "$D" 2>/dev/null | grep -i 'adbd' || echo "  (vendor/lib64/adbd yok)"