#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) link.* satirlari CANLI config'te ==="
A 'grep -n "^link\." /linkerconfig/ld.config.txt | cut -c1-200'
echo ""
echo "=== 2) bootstrap/default kopyalari da guncel MI ==="
A 'for f in /linkerconfig/ld.config.txt /linkerconfig/bootstrap/ld.config.txt /linkerconfig/default/ld.config.txt; do
   [ -f "$f" ] || continue
   echo "  $f: link.default=$(grep -c "^link.default" "$f") link.public=$(grep -c "^link.public" "$f")"
 done'
echo ""
echo "=== 3) com_android_art TAM tanimi ==="
A 'grep -n "^namespace.com_android_art" /linkerconfig/ld.config.txt | head -8 | cut -c1-100'
echo ""
echo "=== 4) ART bu namespace'i NEREDEN ariyor (dizin bazli) ==="
A 'echo "--- apex yolu adindan namespace adi turetmek:"
   echo "  /apex/com.android.art/  ->  com_android_art"
   echo "--- configte tam olarak bu ad var mi:"
   grep -c "^namespace.com_android_art\." /linkerconfig/ld.config.txt'
echo ""
echo "=== 5) bootstrap linker configiyle dene (farkli config) ==="
A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
   echo "--- (A) varsayilan config:"
   timeout 12 /apex/com.android.art/bin/dalvikvm64 -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/head -3
   echo "  RC=$?"
   echo "--- (B) LD_CONFIG_FILE ile canli config:"
   LD_CONFIG_FILE=/linkerconfig/ld.config.txt timeout 12 /apex/com.android.art/bin/dalvikvm64 -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/head -3
   echo "  RC=$?"'