#!/bin/bash
# zygote 'running' ama ps'te [app_process64] koseli parantez icinde
# = komut satiri yok = ZOMBI ya da okunamayan /proc/PID/cmdline.
# Neden oldu? logcat + tombstone.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote ayrintili durum ==="
A 'getprop init.svc.zygote; getprop init.svc.zygote_secondary; getprop init.svc.surfaceflinger; getprop sys.boot_completed'
echo ""
echo "=== 2) zygote logcat ==="
A 'logcat -d 2>/dev/null | grep -iE "zygote|app_process|AndroidRuntime|Fatal" | tail -30'