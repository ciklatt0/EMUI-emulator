#!/bin/bash
# linkerconfig binary'si /apex/apex-info-list.xml okuyor ve
# BASARISIZ oluyor ("Failed to scan APEX modules"). Dosyayi
# sentezleyerek onu calistirabilir miyiz?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) apex-info-list dosyalari sistemde var mi ==="
A 'find /system /vendor /odm /cust /apex /apexfiles -name "apex-info-list*" 2>/dev/null | head -6'
echo ""
echo "=== 2) linkerconfig'in bekledigi XML etiketleri (binaryden) ==="
A 'strings /system/bin/bootstrap/linkerconfig 2>/dev/null | grep -E "^<|apex-instances|apex-info|version=|preInstallDir" | head -10'
echo ""
echo "=== 3) linkerconfig'i elle calistirip hatayi gor ==="
A '/system/bin/bootstrap/linkerconfig --target /tmp/lc 2>&1 | head -6'
echo ""
echo "=== 4) APEX'lerin gercek isimleri (etiket icin) ==="
A 'ls /apex | grep -v "^com.android.adbd$" | head -8'
A 'ls /apex | wc -l'