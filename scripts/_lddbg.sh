#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ld.config.txt BOYUT ve ilk satirlar ==="
A 'ls -l /linkerconfig/ld.config.txt; wc -l /linkerconfig/ld.config.txt'
A 'head -5 /linkerconfig/ld.config.txt'
echo ""
echo "=== 2) apex yolu sayisi ==="
A 'grep -c "apex" /linkerconfig/ld.config.txt'
echo ""
echo "=== 3) awk calisiyor mu? (busybox testi) ==="
A 'echo "a
namespace.default.search.paths = /x
b" | /bb/awk "{print} !d1 && /^namespace\.default\.search\.paths/ {print \"EKLEDI\"; d1=1}" 2>&1'
echo ""
echo "=== 4) busybox awk coklu -v ve cok satirli deger ==="
A 'V="X
Y"; echo "namespace.default.search.paths = /x" | /bb/awk -v ins="$V" "{print} !d && /^namespace.default.search.paths/ {printf \"%s\\n\", ins; d=1}" 2>&1'
echo ""
echo "=== 5) logcat: linkerconfig yeniden yazdi mi ==="
A 'logcat -d 2>/dev/null | grep -i linkerconfig | tail -5'