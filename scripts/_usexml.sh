#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) uretilen config: apex gecen satirlar ==="
A 'grep -n "apex" /tmp/lc/ld.config.txt | head -8'
echo ""
echo "=== 2) [system] bolumu ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s' /tmp/lc/ld.config.txt | head -12"
echo ""
echo "=== 3) DENEY: bu config'i global yap, sonra test ==="
A 'cp /tmp/lc/ld.config.txt /linkerconfig/ld.config.txt
cp /tmp/lc/ld.config.txt /linkerconfig/default/ld.config.txt 2>/dev/null
cp /tmp/lc/ld.config.txt /linkerconfig/bootstrap/ld.config.txt 2>/dev/null
echo yazildi'
echo ""
echo "=== 4) test: 64-bit ikililer baglaniyor mu ==="
A '/system/bin/audioserver --help 2>&1 | head -2'
A '/system/bin/getprop ro.product.model 2>&1 | head -2'
A '/system/bin/surfaceflinger --help 2>&1 | head -2'
echo ""
echo "=== 5) 10 sn sonra yeni uyari / CANNOT LINK ==="
sleep 10
A 'logcat -d 2>/dev/null | grep "failed to find generated linker" | tail -3'
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | tail -3'