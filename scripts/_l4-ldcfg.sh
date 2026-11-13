#!/bin/bash
# ld.config.txt sistemde YOK. Ama Android 10+ APEX kutuphanelerini
# yalnizca ld.config.txt ile bulur. Biz mountapex'te APEX basina
# uretiyoruz ama ANA (/system/etc) olmayabilir.
# Firmware'de gercekten var mi, baska bir yerde mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) sistemdeki TUM ld.config dosyalari ==="
A 'find / -name "ld.config*.txt" 2>/dev/null | head -20'
echo ""
echo "=== 2) apex basina uretigimiz ornek (adbd) ==="
A 'ls -l /apex/com.android.adbd/etc/ 2>&1 | head -5'
A 'head -20 /apex/com.android.adbd/etc/ld.config.txt 2>&1'
echo ""
echo "=== 3) com.android.art icinde ld.config var mi ==="
A 'ls -l /apex/com.android.art/etc/ 2>&1 | head -8'
echo ""
echo "=== 4) /system/etc icinde ne var (linker ile ilgili) ==="
A 'ls /system/etc/ | grep -iE "ld|linker|nativeloader" | head -10'
echo ""
echo "=== 5) linker varsayilan yollari (LD_DEBUG ile dene) ==="
A 'LD_DEBUG=libs /system/bin/app_process64 --help 2>&1 | grep -iE "nativeloader|search|path" | head -10'