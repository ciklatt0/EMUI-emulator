#!/bin/bash
# app_process64 190 kutuphane yukluyor ama libart.so YOK.
# ART VM hiç baslamiyor olabilir. Bunu dogrudan sinayalim:
# dalvikvm64 tam olarak libart'a baglidir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) dalvikvm64 -version (ART'ye dogrudan erisim testi) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   echo "--- /apex/com.android.art/bin/dalvikvm64:"
   /apex/com.android.art/bin/dalvikvm64 -version 2>&1 | head -8
   echo "RC=$?"'
echo ""
echo "=== 2) libart.so'nun ihtiyac duydugu kutuphaneler ==="
A '/system/bin/toybox readelf -d /apex/com.android.art/lib64/libart.so 2>&1 | grep NEEDED | head -20'
echo ""
echo "=== 3) bu ihtiyaclardan HANGILERI eksik? (diskte var mi) ==="
A 'for l in libartbase.so libartpalette.so libdexfile.so libprofile.so libsigchain.so libnativehelper.so libnativeloader.so libc++.so liblzma.so libz.so libcrypto.so libbase.so; do
   F=$(find /apex /system -maxdepth 3 -name "$l" 2>/dev/null | head -1)
   [ -n "$F" ] && echo "  $l -> $F" || echo "  $l -> YOK"
 done'
echo ""
echo "=== 4) libart.so'nun ELF turu ve boyutu ==="
A '/system/bin/toybox file /apex/com.android.art/lib64/libart.so 2>&1
   ls -l /apex/com.android.art/lib64/libart.so'