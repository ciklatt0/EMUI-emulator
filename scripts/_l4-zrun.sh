#!/bin/bash
# Zygote'yi elle, stderr'i YAKALAYARAK calistir. Tombstone yok
# (/data her vold cokmesinde sifirlaniyor), ama elle calistirip
# ciktisini okumak daha dogrudan.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote'yi elle calistir (env ile) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; \
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zygote 2>&1 | head -30'