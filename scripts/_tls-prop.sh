#!/bin/bash
# Adbd'nin TCP oncesi bekledigi ozellik: persist.adb.tls_server.enable
# Log: "adb_wifi.cpp:196] Waiting for persist.adb.tls_server.enable=1"
# Bu ozelligi biz ayarlamazsak adbd varsayilan degerin ne oldugunu
# bilmiyoruz -- firmware'in property_contexts/prop.default'inda var mi?
set -u
D=/root/harmony-build/boot/system-disk.img
SOFF=1048576
echo "=== /system/build.prop'ta tls_server ==="
dump.erofs --offset=$SOFF --cat --path=/system/build.prop "$D" 2>/dev/null | grep -i 'tls\|adb'
echo ""
echo "=== /vendor/build.prop'ta tls_server ==="
dump.erofs --offset=$((11806720*512)) --cat --path=/build.prop "$D" 2>/dev/null | grep -i 'tls\|adb'
echo ""
echo "=== /system/etc/prop.default ==="
dump.erofs --offset=$SOFF --cat --path=/system/etc/prop.default "$D" 2>/dev/null | grep -i 'tls\|adb'
echo ""
echo "=== adbd ikilisindeki tls_server dizeleri ==="
strings -a /root/harmony-build/apex/bin/adbd 2>/dev/null | grep -i 'tls_server' | head -5 \
  || echo "  (yerel adbd yok)"