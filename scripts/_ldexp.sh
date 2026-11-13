#!/bin/bash
# CANLI DENEY: permitted.paths eklemeleri config'i BOZUYOR mu?
# 1) mevcut ( permitted ekli) ile app_process calistir
# 2) permitted eklerini cikar, tekrar calistir
# Fark, dogrudan kanit.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) MEVCUT config (permitted ekli) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; /system/bin/app_process64 --help 2>&1 | head -4'

echo ""
echo "=== 2) permitted satirlarini CIKAR, yeniden dene ==="
A 'cp /linkerconfig/ld.config.txt /tmp/ld.bak
/bb/grep -v "^namespace.default.permitted.paths += /apex/" /tmp/ld.bak > /tmp/ld.np
wc -l /tmp/ld.bak /tmp/ld.np'
A 'cp /tmp/ld.np /linkerconfig/ld.config.txt; echo "yazildi"'

echo ""
echo "=== 3) permitted OLMADAN app_process ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; /system/bin/app_process64 --help 2>&1 | head -4'

echo ""
echo "=== 4) simdi permitted'li OLANI geri koy ==="
A 'cp /tmp/ld.bak /linkerconfig/ld.config.txt; echo "geri kondu"'
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; /system/bin/app_process64 --help 2>&1 | head -4'