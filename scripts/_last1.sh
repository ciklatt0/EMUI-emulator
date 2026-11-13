#!/bin/bash
# permitted.paths hipotezi REDDEDILDI (art/lib64 her iki
# listede de var). Simdi linker'in KENDI "cannot locate"
# gunlukleri ve ART boot image var mi olcuyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) linker 'cannot locate' / libart gunlukleri ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "cannot locate|libart|dlopen|cannot open shared" | grep -v "avc:" | tail -12; echo "(bos ise linker hic sey demiyor)"'
echo ""
echo "=== 2) ART boot image / imagepath ==="
A 'getprop | grep -E "dalvik.vm.image|dalvik.vm.boot|dalvik.vm.dex2oat|ro.dalvik.vm" | head -10'
echo "--- dosya kontrolu:"
ls -l /system/framework/boot.art /system/etc/art-image-* /apex/com.android.art/etc/art-image-* 2>&1 | head -6'
echo ""
echo "=== 3) /apex/com.android.art/etc icinde ne var ==="
A 'ls /apex/com.android.art/etc/ 2>&1 | head -10'
echo ""
echo "=== 4) javalib (core-oj / CONVEX) ==="
A 'ls /apex/com.android.art/javalib/ 2>&1 | head -8
   echo "--- core-oj:"; ls -l /apex/com.android.art/javalib/core-oj.* 2>&1 | head -3'
echo ""
echo "=== 5) system_server sinifi + zygote'un system_server'a ekledigi ANDROID_SOCKET ==="
A 'ls -l /system/framework/services.jar 2>&1
   echo "--- odex/jar:"; ls /system/framework/*.jar 2>/dev/null | head -6'
echo ""
echo "=== 6) zygote sonrasi: init ne diyor (son 5 cikis) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -a "Service 'zygote'" "$F" | tail -3 | sed 's/\[[^]]*\] //' | cut -c1-110