#!/bin/bash
# L5'e ULASTIK. Simdi L5 uzerinden sistemi gez ve L4'e dogru
# ilerlemeye calis (Zygote + SystemServer).
ADB="${ADB:-adb}"
S="127.0.0.1:5555"
sh_() { "$ADB" -s "$S" shell "$@" 2>&1 | tr -d '\r'; }

echo "=== L5 KANITI ==="
sh_ "echo L5-CALISIYOR; whoami; id"
echo ""
echo "=== bellek / disk ==="
sh_ "free -m 2>/dev/null | head -3; df -h /data /system 2>/dev/null | head -4"
echo ""
echo "=== L4: zygote var mi? ==="
sh_ "ps -A 2>/dev/null | grep -iE 'zygote|system_server|surfaceflinger' | head -5"
echo ""
echo "=== servis durumu (init.svc) ==="
sh_ "getprop 2>/dev/null | grep -c . ; getprop init.svc.adbd; getprop init.svc.zygote; getprop init.svc.surfaceflinger"
echo ""
echo "=== /system erisilebilir mi ==="
sh_ "ls /system/bin 2>/dev/null | wc -l; ls /apex 2>/dev/null | wc -l; ls /data 2>/dev/null | head -3"