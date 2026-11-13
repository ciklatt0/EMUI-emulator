#!/bin/bash
# ART VM ARTUK CALISIYOR (dalvikvm64 ile). Iki somut engel var:
#  1) boot.art "component count 5, expected <= 3"
#  2) core-oj.jar / core-libart.jar /system/frameworkde YOK
# Once dogru dosyalari bulalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /apex/com.android.art/javalib icerigi ==="
A 'ls -l /apex/com.android.art/javalib/ 2>&1 | head -20'
echo ""
echo "=== 2) core-oj.jar / core-libart.jar / framework.jar NEREDE ==="
A 'for f in core-oj.jar core-libart.jar core-oj.odex core-libart.oat framework.jar; do
   P=$(find /apex /system -maxdepth 4 -name "$f" 2>/dev/null | head -1)
   printf "  %-22s %s\n" "$f" "${P:-YOK}"
 done'
echo ""
echo "=== 3) boot.art icerigi (component sayisi) ==="
A 'ls -l /apex/com.android.art/javalib/boot.art /apex/com.android.art/javalib/arm64/boot.art 2>&1 | head -3
   echo "  --- boot art dizini:"
   ls -l /apex/com.android.art/javalib/arm64/ 2>&1 | head -10'
echo ""
echo "=== 4) Android 12 dogru bootclasspath (javalib + framework) ==="
A 'ls /system/framework/*.jar 2>/dev/null | /bb/head -12'
echo ""
echo "=== 5) DALVIK_VM_IMAGE_PATH ozelligi (boot.art yolu) ==="
A 'getprop | grep -iE "boot.art|boot-image|imagepath|image.dir" | head -8
   echo "  --- /system/etc/boot-image.prof:"
   ls -l /system/etc/boot-image.prof 2>&1 | head -1'