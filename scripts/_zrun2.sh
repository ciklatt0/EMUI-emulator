#!/bin/bash
# Tombstone dolu degil; elle calistirip stderr'i yakalamak daha dogrudan.
# /data dizinleri bu kez KALICI (mount idempotent yapildi), yani
# 'dalvik-cache' hatasi gelmemeli; yeni abort mesajini gorelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /data dalvik-cache gercekten var mi ==="
A 'ls -d /data/dalvik-cache/arm64 && echo VAR'
echo ""
echo "=== 2) zygote'yi elle calistir, stderr YAKALA ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; \
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zygote 2>&1 | head -40'