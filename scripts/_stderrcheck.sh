#!/bin/bash
# OLÇÜM ARACI DOGRULAMASI: adb shell stderr'i gosteriyor mu?
# Bu tum seansta onemli: eger gostermiyorsa butun "sessiz cokme"
# tespitlerimiz yanlisti.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) KONTROL: stdout + stderr ayri ==="
A 'echo "STDOUT_MARKER"; echo "STDERR_MARKER" >&2'
echo ""
echo "=== 2) KONTROL: yalnizca stderr ==="
A '/system/bin/sh -c "echo YALNIZCA_STDERR >&2"'
echo ""
echo "=== 3) app_process64 --help stderr'e yaziyor mu ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 12 /system/bin/app_process64 --help 2>&1 | head -8; echo "RC=${PIPESTATUS[0]:-?}"'
echo ""
echo "=== 4) busybox timeout gercekten RC donuyor mu ==="
A 'timeout 3 /system/bin/sh -c "exit 7"; echo "RC=$? (7 olmali)"'
echo ""
echo "=== 5) app_process64 dogrudan, boru HARIcinI ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 12 /system/bin/app_process64 > /tmp/ap.out 2> /tmp/ap.err; echo "RC=$?"; echo "--- stdout ($(wc -c < /tmp/ap.out) bayt)"; cat /tmp/ap.out; echo "--- stderr ($(wc -c < /tmp/ap.err) bayt)"; cat /tmp/ap.err'