#!/bin/bash
# L4 teşhisi: zygote neden başlamıyor?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) servis durumlari ==="
A 'getprop init.svc.zygote; getprop init.svc.surfaceflinger; getprop init.svc.bootanim; getprop init.svc.netd; getprop init.svc.installd; getprop sys.boot_completed'
echo ""
echo "=== 2) zygote ikilisi var mi ==="
A 'ls -l /system/bin/zygote* /system/bin/app_process* /system/bin/start 2>&1 | head -6'
echo ""
echo "=== 3) zygote rc tanimi ==="
A 'grep -rl "service zygote" /system/etc/init /vendor/etc/init 2>/dev/null | head -3'
echo ""
echo "=== 4) class durumu (class_start tetiklendi mi) ==="
A 'getprop | grep -i "class" | head -5'
echo ""
echo "=== 5) son init mesajlari ==="
A 'logcat -d -b main -t 25 2>/dev/null | tail -25'