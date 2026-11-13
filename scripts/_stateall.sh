#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) L5 ==="
A 'getprop ro.product.model; getprop init.svc.adbd; getprop sys.boot_completed'
echo ""
echo "=== 2) calisan servisler ==="
A 'getprop | grep "\[init.svc" | grep running'
echo ""
echo "=== 3) restarting/stopped olanlar ==="
A 'getprop | grep "\[init.svc" | grep -E "restarting" | head -10'
echo ""
echo "=== 4) surecler ==="
A 'ps -A 2>/dev/null | grep -E "servicemanager|zygote|adbd|audioserver" | head -8'
echo ""
echo "=== 5) son init mesajlari ==="
A 'logcat -d 2>/dev/null | grep -iE "init:" | tail -8'