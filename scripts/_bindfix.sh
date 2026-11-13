#!/bin/bash
# linkerconfig bind rec iptal edildi. /linkerconfig mount sayisi
# 1 olmali. CANNOT_LINK ve zygote durumu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /linkerconfig mount sayisi (1 olmali) ==="
A 'grep -c " /linkerconfig " /proc/mounts; mount | grep linkerconfig'
echo ""
echo "=== 2) CANNOT LINK sayisi (0 olmali) ==="
A 'logcat -d 2>/dev/null | grep -c "CANNOT LINK"'
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | sed "s/.*EXECUTABLE \"//;s/\".*//" | sort | uniq -c | head -5'
echo ""
echo "=== 3) linkerconfig uyarisi ==="
A 'logcat -d 2>/dev/null | grep -c "failed to find generated linker"'
echo ""
echo "=== 4) servisler ==="
A 'getprop | grep "\[init.svc" | grep running | head -14'
echo ""
echo "=== 5) zygote + system_server ==="
A 'getprop init.svc.zygote; ps -A 2>/dev/null | grep -iE "system_server|runtime-init" | grep -v "sh -c" | head -3; echo "(bos ise system_server yok)"'