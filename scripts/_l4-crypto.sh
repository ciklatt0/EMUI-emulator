#!/bin/bash
# linker duzeldi. Simdi: zygote NEDEN baslamiyor?
# hw/init.rc'de: on zygote-start && property:ro.crypto.state=unencrypted
#                start zygote
# yani ro.crypto.state dogru degilse zygote tetiklenmez.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) crypto ozellikleri (zygate tetikleyicisi bunlara bagli) ==="
A 'getprop ro.crypto.state; getprop ro.crypto.type; getprop ro.crypto.mount'
echo ""
echo "=== 2) zygote tanimli mi ==="
A 'getprop init.svc.zygote; getprop init.svc.zygote_secondary'
echo ""
echo "=== 3) elle baslatmayi dene ==="
A 'setprop ctl.start zygote; sleep 10; getprop init.svc.zygote'
echo ""
echo "=== 4) zygote process + system_server ==="
A 'ps -A 2>/dev/null | grep -E "app_process|system_server" | head -6'
echo ""
echo "=== 5) zygote hata mesaji ==="
A 'logcat -d 2>/dev/null | grep -iE "zygote|AndroidRuntime|SystemServer|DALVIK" | tail -20'