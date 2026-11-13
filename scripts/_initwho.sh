#!/bin/bash
# /r/system/bin init kim baslatiyor? CANNOT LINK cevresindeki
# 10 satiri goster.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) CANNOT LINK init cevresi (ham) ==="
A 'logcat -d 2>/dev/null | grep -B 3 -A 3 "CANNOT LINK EXECUTABLE \"/r/system/bin/init\"" | tail -18'
echo ""
echo "=== 2) process listede init var mi ==="
A 'ps -A 2>/dev/null | grep -w init | head -5'
echo ""
echo "=== 3) /system/bin/init calistirilabilir mi elle (--help yok, suresi dolu) ==="
A 'ls -l /r/system/bin/init; echo "---"; /bb/cat /proc/1/cmdline 2>/dev/null | /bb/tr "\0" " "'
echo ""
echo "=== 4) vendor_init baglaminda calisan servisler ==="
A 'getprop | grep "\[init.svc" | grep -E "restarting|stopped" | head -12'