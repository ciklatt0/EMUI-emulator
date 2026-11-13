#!/bin/bash
# L4 dogrulama: zygote import'u kurtarildi mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) rc yamalama logu (cozulen degerler) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -E "cozulen|somutlastirilamadi|rc dosyasi|import" "$F" 2>/dev/null | head -5

echo ""
echo "=== 1) master rc'de zygote import'u ARTIK yorumlu mu? ==="
A 'grep -n "zygote" /system/etc/init/hw/init.rc | head -4'

echo ""
echo "=== 2) zygote SERVISI tanimli mi ==="
A 'setprop ctl.start zygote; sleep 8; getprop init.svc.zygote'

echo ""
echo "=== 3) zygote / app_process / system_server surecleri ==="
A 'ps -A 2>/dev/null | grep -iE "zygote|app_process|system_server" | head -6'

echo ""
echo "=== 4) boot ilerlemesi ==="
A 'getprop init.svc.surfaceflinger; getprop sys.boot_completed; getprop dev.bootcomplete; getprop init.svc.bootanim'