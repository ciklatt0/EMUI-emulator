#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) TANIMLANAN servis sayisi (once 38) ==="
A 'getprop | grep -c "\[init.svc"'
echo ""
echo "=== 2) donanim rc importu cozuldu mu ==="
A 'grep -n "import" /system/etc/init/hw/init.rc | head -10'
echo ""
echo "=== 3) system_server var mi ==="
A 'ps -A 2>/dev/null | grep -iE "system_server|zygote" | head -5'
echo ""
echo "=== 4) boot ilerlemesi ==="
A 'getprop sys.boot_completed; getprop dev.bootcomplete; getprop init.svc.surfaceflinger; getprop init.svc.bootanim'
echo ""
echo "=== 5) system_server izleri ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "SystemServer|system_server|boot_progress|PackageManager|ActivityManager" | tail -10'