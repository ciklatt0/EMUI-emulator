#!/bin/bash
# /system/etc icinde ld.config.txt var mi? Linker varsayilan olarak
# ANDROID_ROOT/etc/ld.config.txt adresini okur; biz /linkerconfig
# altina yaziyoruz. Ikisi ayni sey mi?
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=1048576
echo "--- /system (nid 768) ---"
dump.erofs --offset=$OFF --ls --nid=768 "$D" 2>/dev/null | grep -iE 'etc|linker'
echo ""
echo "--- /system/etc (nid 28563591) icinde 'ld' gecenler ---"
dump.erofs --offset=$OFF --ls --nid=28563591 "$D" 2>/dev/null | grep -i 'ld\.'
echo ""
echo "--- linker64'nin aradigi varsayilan yol ---"
echo "  ANDROID_ROOT/etc/ld.config.txt  ->  /system/etc/ld.config.txt"
echo "  biz yaziyoruz                   ->  /linkerconfig/ld.config.txt"