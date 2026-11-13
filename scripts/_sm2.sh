#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) linker tarafindan gorulen bolumler (canli) ==="
A 'grep -n "^\[" /linkerconfig/ld.config.txt'
echo ""
echo "=== 2) [vendor] bolumu tam ==="
A "awk '/^\[vendor\]/{s=1;next} /^\[/{s=0} s' /linkerconfig/ld.config.txt | cut -c1-110"
echo ""
echo "=== 3) servicemanager ikilisi ve baglami ==="
A 'ls -l /system/bin/servicemanager 2>&1'
echo ""
echo "=== 4) elle calistir (hata mesalesi) ==="
A '/system/bin/servicemanager 2>&1 & sleep 4; pidof servicemanager; kill %1 2>/dev/null'
echo ""
echo "=== 5) ueventd neden restarting ==="
A '/system/bin/ueventd 2>&1 | head -5'