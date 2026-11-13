#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) yeni Abort mesajlari ==="
A 'logcat -d 2>/dev/null | grep -E "Abort message" | tail -5'
echo ""
echo "=== 2) zygote'nin ORTAMI (setenv ise yaradi mi) ==="
A 'p=$(pidof app_process64 2>/dev/null | tr " " "\n" | head -1); echo "pid=$p"'
A 'p=$(pidof app_process64 2>/dev/null | tr " " "\n" | head -1); tr "\0" "\n" < /proc/$p/environ 2>/dev/null | grep -E "ANDROID_(DATA|ROOT|RUNTIME)" '
echo ""
echo "=== 3) elle calistir + ortami goster (kontrol) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; echo "elle: ANDROID_DATA=$ANDROID_DATA"'
echo ""
echo "=== 4) zygote sonrasi ne oluyor (system_server fork edildi mi) ==="
A 'logcat -d 2>/dev/null | grep -iE "SystemServer|ActivityManager|SysServer|zygote.*fork|PreloadedSystemServer" | tail -8'