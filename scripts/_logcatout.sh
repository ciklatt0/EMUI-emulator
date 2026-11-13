#!/bin/bash
# app_process64 3 sn sonra RC=0 ile cikiyor; 16 KB ikili icin bu
# ART runtime yuklemesi demek. Huawei mesajlari stderr yerine
# LOGCAT'e yaziyor olabilir. Ciktinin gitmedigi yeri arayalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) logcat temizle ==="
A 'logcat -c 2>/dev/null; echo ok'
echo ""
echo "=== 1) app_process64 --help calistir ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; timeout 12 /system/bin/app_process64 --help; echo "RC=$?"'
echo ""
echo "=== 2) O AN logcat'te ne var (app_process/zygote/art) ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:|wificond|HiTrace" | tail -25'