#!/bin/bash
# 'Error creating cache dir /data/dalvik-cache/arm64'
# /data icinde ne var? mkdir calisiyor mu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /data mount durumu ==="
A 'cat /proc/mounts | grep " /data "'
echo ""
echo "=== 2) /data icerigi ==="
A 'ls -la /data 2>&1 | head -20'
echo ""
echo "=== 3) mkdir denemesi ==="
A 'mkdir -p /data/dalvik-cache/arm64 2>&1 && echo "MKDIR TAMAM" || echo "MKDIR BASARISIZ"'
echo ""
echo "=== 4) mkdir sonrasi tekrar zygote ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; \
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zygote 2>&1 | head -25'