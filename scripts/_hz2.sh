#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /apex/com.android.art icinde NE VAR ==="
A 'ls /apex/com.android.art/ 2>&1
   echo "--- bin:"; ls /apex/com.android.art/bin/ 2>&1 | head -10
   echo "--- lib64 (ilk 12):"; ls /apex/com.android.art/lib64/ 2>&1 | head -12
   echo "--- libart.so var MI:"; ls -l /apex/com.android.art/lib64/libart.so 2>&1'
echo ""
echo "=== 2) YUKLENEN TUM .so'lar (app_process64, 1 sn sonra) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zn1 >/dev/null 2>&1 &
   ZP=$!; /bb/sleep 1
   { if [ -d /proc/$ZP ]; then
       grep -oE "/[a-zA-Z0-9._/+-]+\.so" /proc/$ZP/maps 2>/dev/null | sort -u
     else echo "  (1 sn icinde oldu)"; fi; } > /tmp/zn.txt 2>&1
   kill -9 $ZP 2>/dev/null; wait $ZP 2>/dev/null
   echo "--- yuklenen kutuphane sayisi: $(wc -l < /tmp/zn.txt)"
   cat /tmp/zn.txt' 2>&1 | head -60
echo ""
echo "=== 3) app_process64 hangi kutuphaneleri yuklemeye CALISIYOR (strings) ==="
A 'strings /system/bin/app_process64 2>/dev/null | grep -E "^lib.*\.so$" | sort -u | head -20'