#!/bin/bash
# Zygote'yi elle baslatip OLMESI GEKEN hatayi yakala.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote rc tanimi (tam) ==="
A 'cat /system/etc/init/hw/init.zygote64_32.rc 2>/dev/null | head -25'
echo ""
echo "=== 2) onceki durum ==="
A 'getprop init.svc.zygote'
echo ""
echo "=== 3) BASLAT: ctl.start zygote ==="
A 'setprop ctl.start zygote; sleep 6; getprop init.svc.zygote'
echo ""
echo "=== 4) zygote/boot orta sureci var mi ==="
A 'ps -A 2>/dev/null | grep -iE "zygote|app_process|system_server" | head -5'
echo ""
echo "=== 5) zygote HATASI (logcat) ==="
A 'logcat -d 2>/dev/null | grep -iE "zygote|app_process|Unable to|abort|Fatal|denied" | tail -25'