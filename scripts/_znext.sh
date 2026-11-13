#!/bin/bash
# zygote artik ABORT olmuyor; ANDROID_DATA duzeltmesi tuttu.
# Simdi: 'exited with status 0' -- yani zygote kendi istegine
# gore kapatiyor. Genellikle system_server fork basarisiz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) canli zygote ayrinti ==="
A 'ps -A 2>/dev/null | grep -E "app_process|zygote" | head -5'
echo ""
echo "=== 2) logcat: ZygoteInit / system_server ==="
A 'logcat -d 2>/dev/null | grep -iE "ZygoteInit|system_server|SystemServer|Late-enabling|Preload|Forking|Welcome to" | tail -15'
echo ""
echo "=== 3) son AndroidRuntime / hatalar ==="
A 'logcat -d 2>/dev/null | grep -E "AndroidRuntime|F libc|Abort message|Unable to" | grep -v avc | tail -12'
echo ""
echo "=== 4) zygote ortami (ANDROID_DATA geldi mi) ==="
A 'p=$(ps -A 2>/dev/null | grep app_process | head -1 | tr -s " " | cut -d" " -f2); echo "pid=$p"'
A 'p=$(ps -A 2>/dev/null | grep app_process | head -1 | tr -s " " | cut -d" " -f2); tr "\0" "\n" < /proc/$p/environ 2>/dev/null | grep -E "ANDROID_(DATA|ROOT|RUNTIME|SOCKET)" '
echo ""
echo "=== 5) android_env sayaci (rc yamalama logu) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -E "android_env|APEX yolu|import somutlastirilamadi|cozulen" "$F" | head -5 | sed 's/\[[^]]*\] //'