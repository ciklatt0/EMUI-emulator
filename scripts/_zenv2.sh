#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /init.environ.rc icinde setenv ANDROID_DATA var mi ==="
A 'grep -n "setenv" /init.environ.rc'
echo ""
echo "=== 2) init bu komutlari kabul etti mi (hata var mi) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -aiE "setenv|Invalid keyword|Unknown command|Failed to setenv" "$F" | head -10 | cut -c1-160
echo ""
echo "=== 3) LD_LIBRARY_PATH (setenv'in CALISTIGININ kaniti) nerede tanimli ==="
A 'grep -n "LD_LIBRARY_PATH" /init.environ.rc'
echo ""
echo "=== 4) calisan bir servisin tam ortami ==="
A 'p=$(pidof logd 2>/dev/null | head -1); tr "\0" "\n" < /proc/$p/environ 2>/dev/null'