#!/bin/bash
# /system bind mount sonrasi: L5 + L4 durumu
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /system gercek mount noktasi MI ==="
A 'ls -ld /system; readlink /system; mount | grep -c " /system "'
echo ""
echo "=== 2) calisan servisler ==="
A 'getprop | grep "\[init.svc" | grep running'
echo ""
echo "=== 3) CANNOT LINK (0 olmali) ==="
A 'logcat -d 2>/dev/null | grep -c "CANNOT LINK"'
echo ""
echo "=== 4) zygote + system_server ==="
A 'getprop init.svc.zygote; ps -A 2>/dev/null | grep -iE "system_server|runtime-init" | grep -v "sh -c" | head -3; echo "(bos ise yok)"'
echo ""
echo "=== 5) restarting/stopped ==="
A 'getprop | grep "\[init.svc" | grep -E "restarting|stopped" | head -10'
echo ""
echo "=== 6) system_server izleri ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "SystemServer|system_server|boot_progress|PackageManager" | tail -8'