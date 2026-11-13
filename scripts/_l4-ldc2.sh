#!/bin/bash
# /system/etc/ld.config.txt YOK. Firmware linker.config.pb kullaniyor
# (Android 11+ modeli). /linkerconfig/ld.config.txt var -- kim uretti,
# icinde art APEX yolu var mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /linkerconfig/ld.config.txt ==="
A 'ls -l /linkerconfig/ld.config.txt 2>&1'
A 'wc -l /linkerconfig/ld.config.txt 2>&1'
echo ""
echo "=== 2) icinde art apex yolu var mi ==="
A 'grep -c "com.android.art" /linkerconfig/ld.config.txt 2>&1'
A 'grep -o "com.android.art/lib64" /linkerconfig/ld.config.txt 2>&1 | head -3'
echo ""
echo "=== 3) ilk 25 satir ==="
A 'head -25 /linkerconfig/ld.config.txt 2>&1'
echo ""
echo "=== 4) /system/etc erisilebilir mi (yazilabilir) ==="
A 'ls -ld /system/etc; touch /system/etc/.wtest 2>&1 && echo "YAZILABILIR" && rm -f /system/etc/.wtest || echo "YAZILAMAZ"'