#!/bin/bash
# Kalici cozumler calisiyor mu? zygote OTOMATIK baslamali
# (ro.crypto.state=unencrypted + /data/dalvik-cache/arm64 mkdir).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ro.crypto.state (zygate tetikleyicisi) ==="
A 'getprop ro.crypto.state; getprop ro.crypto.type'
echo ""
echo "=== 2) /data dizinleri ==="
A 'ls /data 2>&1 | head -14'
echo ""
echo "=== 3) zygote OTOMATIK basladi mi (elle baslatmadan) ==="
A 'getprop init.svc.zygote'
echo ""
echo "=== 4) surecler ==="
A 'ps -A 2>/dev/null | grep -E "app_process|system_server" | head -8'
echo ""
echo "=== 5) boot ilerlemesi ==="
A 'getprop sys.boot_completed; getprop init.svc.surfaceflinger; getprop dev.bootcomplete; getprop init.svc.bootanim'