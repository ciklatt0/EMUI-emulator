#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) liblog.so nerede ==="
A 'find /system /apex /vendor -name "liblog.so" 2>/dev/null | head -5'
echo ""
echo "=== 2) [vendor] bolumunun tam hali ==="
A "awk '/^\[vendor\]/{s=1;next} /^\[/{s=0} s' /linkerconfig/ld.config.txt | cut -c1-150"
echo ""
echo "=== 3) [vendor] search.paths icinde /system var MI ==="
A "awk '/^\[vendor\]/{s=1;next} /^\[/{s=0} s && /search\.paths/' /linkerconfig/ld.config.txt | tr ':' '\n' | grep -c system"
echo ""
echo "=== 4) /vendor/lib64 icinde ne var ==="
A 'ls /vendor/lib64/ 2>/dev/null | head -6; ls /vendor/lib64/liblog* 2>&1 | head -2'
echo ""
echo "=== 5) sistem lib64 liblog var MI ==="
A 'ls -l /system/lib64/liblog.so 2>&1'