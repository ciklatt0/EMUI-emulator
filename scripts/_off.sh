#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) adbd durumu ==="
A 'getprop init.svc.adbd; ps -A 2>/dev/null | grep adbd | head -3'
echo ""
echo "=== 2) adbd logcat (AVC disi) ==="
A 'logcat -d -b all 2>/dev/null | grep -i adbd | grep -v "avc:" | tail -15'
echo ""
echo "=== 3) 5555 dinleyici mi ==="
A '/system/bin/toybox netstat -ltn 2>/dev/null | head -6'
echo ""
echo "=== 4) data dizinleri ==="
A 'ls /data 2>&1 | head -8'
echo ""
echo "=== 5) zygote / linker durumu ==="
A 'getprop init.svc.zygote; logcat -d 2>/dev/null | grep -c "CANNOT LINK"'