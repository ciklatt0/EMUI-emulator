#!/bin/bash
# DIKKAT: onceki olcumde ciktiyi KENDIM >/dev/null 2>&1 ile
# bastirmistim; "no output" bulgusu benim hatamdı. Yeniden olcuyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) app_process64 argumansiz (cikti ACIK) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 12 /system/bin/app_process64; echo "RC=$?"'