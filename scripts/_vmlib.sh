#!/bin/bash
# app_process64 -> libandroid_runtime.so -> AndroidRuntime::start()
# VM yolunu belirlemek icin "ro.dalvik.vm.library" OZELLIGINI okur.
# Bu ozellik APEX'e tasindikten sonra BAYAT bir yol (/system/lib64/
# libart.so) gosteriyorsa dlopen SESSIZCE basarisiz olur --
# tam da OLCULEN davranis.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) TUM dalvik.vm.* ozellikleri ==="
A 'getprop | grep -E "^\[dalvik" | head -25'
echo ""
echo "=== 2) ro.dalvik.vm.library var MI, degeri ne ==="
A 'echo "ro.dalvik.vm.library   = [$(getprop ro.dalvik.vm.library)]"
   echo "ro.dalvik.vm.native.bridge = [$(getprop ro.dalvik.vm.native.bridge)]"
   echo "ro.dalvik.vm.dex2oat-threads = [$(getprop ro.dalvik.vm.dex2oat-threads)]"
   echo "--- bu yol diskte var MI:"
   for f in "$(getprop ro.dalvik.vm.library)" /system/lib64/libart.so /apex/com.android.art/lib64/libart.so; do
     [ -f "$f" ] && echo "    VAR  $f" || echo "    YOK  $f"
   done'
echo ""
echo "=== 3) libandroid_runtime.so: VM secimiyle ilgili dizeler ==="
A 'strings /system/lib64/libandroid_runtime.so 2>/dev/null | grep -iE "^libart|dalvik.vm.library|dlopen|libart.so|ART_RUNTIME|ark" | head -20'
echo ""
echo "=== 4) /system/lib64 icinde libart* var MI ==="
A 'ls /system/lib64/ | grep -iE "^libart|^libdexfile|^libprofile" | head -8; echo "  (bos ise /system/lib64 altinda ART kalmamis = APEXe tasinmis)"'