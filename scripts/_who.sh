#!/bin/bash
# ld.config.txt'i kim bozuyor? init kendi linkerconfig komutunu
# calistiriyor olabilir (biz 1 saniyede geri yaziyoruz, ama o
# arada surecler duz config'i gormuyor).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) log: linkerconfig sifirlama uyarisi ==="
grep -aE "SIFIRLADI|ld.config.txt yamalan|apex/etc dizinine" "$F" | tail -8 | sed 's/\[[^]]*\] //' | cut -c1-120
echo ""
echo "=== 2) apex-info-list.xml var mi (linkerconfig bunu okuyor) ==="
A 'ls -l /system/apex/apex-info-list.xml /apex/apex-info-list.xml 2>&1'
echo ""
echo "=== 3) logcat: linkerconfig mesaji ==="
A 'logcat -d 2>/dev/null | grep -i linkerconfig | tail -5'
echo ""
echo "=== 4) rc icinde linkerconfig servisi ==="
A 'grep -rn "linkerconfig" /system/etc/init/*.rc /system/etc/init/hw/*.rc 2>/dev/null | head -6'