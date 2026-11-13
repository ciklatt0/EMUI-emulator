#!/bin/bash
# Android 12 linker config arama sirasi:
#  1. LD_CONFIG_FILE env
#  2. /data/property/ld.config.<ro.product.device>
#  3. /system/etc/ld.config.<ro.product.device>
#  4. /vendor/etc/ld.config.<ro.product.device>
#  5. /linkerconfig/ld.config.txt  (son care)
# Baska bir config kullaniliyor olabilir!
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'DEV=$(getprop ro.product.device 2>/dev/null; getprop ro.hardware 2>/dev/null)
   echo "  device=$DEV"
   echo ""
   echo "=== 1) config adaylari ==="
   for p in /data/property/ld.config.* /system/etc/ld.config.* /vendor/etc/ld.config.* /linkerconfig/ld.config.txt; do
     if [ -e "$p" ]; then
       echo "  VAR: $p"
       /bb/grep -c "link.public\|link.default\|^\[apex\]" "$p" 2>/dev/null | /bb/tr "\n" " "
       echo ""
     fi
   done
   echo "  (yoksa sadece /linkerconfig kullanilir)"
   echo ""
   echo "=== 2) /system/etc/ld.config* icerigi (varsa) ==="
   ls /system/etc/ld.config* 2>&1 | head -5
   echo ""
   echo "=== 3) LD_CONFIG_FILE ile canli configi zorla, fark var MI ==="
   J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
   timeout 30 /apex/com.android.art/bin/dalvikvm64 -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/grep -c "no namespace called"
   echo "  (0 = hata yok, >0 = hata var)"
'