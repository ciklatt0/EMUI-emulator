#!/system/bin/sh
echo "=== logcat: son 50 satir (system_server/zygote/art ile ilgili) ==="
logcat -d -t 50 2>/dev/null | grep -iE "system_server|zygote|ZygoteInit|runtime|artd|boot_preload|Fatal|CANNOT|failed|error|Error" | grep -v "avc:" | head -30
echo ""
echo "=== logcat: crash buffer ==="
logcat -d -b crash -t 20 2>/dev/null | grep -v "avc:" | head -20
echo ""
echo "=== init servis durumlari ==="
getprop init.svc.zygote 2>/dev/null
getprop init.svc.system_server 2>/dev/null
getprop init.svc.arkinit 2>/dev/null
