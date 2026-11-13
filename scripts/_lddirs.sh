#!/bin/bash
# CANLI DENEY: iyi config'i /linkerconfig/default/ ve
# /linkerconfig/bootstrap/ altina da kopyalayip uyariyi say.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) denemeden once uyari sayisi ==="
A 'logcat -d 2>/dev/null | grep -c "failed to find generated linker"'
echo ""
echo "=== 2) default/ ve bootstrap/ dizinleri ==="
A 'ls -ld /linkerconfig/default /linkerconfig/bootstrap 2>&1'
A 'ls -l /linkerconfig/default/ /linkerconfig/bootstrap/ 2>&1 | head -8'
echo ""
echo "=== 3) test: iki yere de kopyala ==="
A 'mkdir -p /linkerconfig/default /linkerconfig/bootstrap
cp /linkerconfig/ld.config.txt /linkerconfig/default/ld.config.txt
cp /linkerconfig/ld.config.txt /linkerconfig/bootstrap/ld.config.txt
echo "yazildi"; ls -l /linkerconfig/default/ld.config.txt /linkerconfig/bootstrap/ld.config.txt'
echo ""
echo "=== 4) yeni surecler denesin (5 sn) ==="
A '/system/bin/audioserver --help 2>&1 | head -2; /system/bin/ueventd 2>&1 | head -2'
echo ""
echo "=== 5) 8 sn sonra yeni uyari var mi ==="
sleep 8
A 'logcat -d 2>/dev/null | grep "failed to find generated linker" | tail -4'