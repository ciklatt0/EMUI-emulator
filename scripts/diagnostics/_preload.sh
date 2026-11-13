#!/bin/bash
# LD_PRELOAD=libart.so (sadece isim; dlopen("libart.so") calisti oldugu icin
# default namespace'de bulunabiliyor). InitNativeMethods'teki
# LoadNativeLibrary("libart.so") cagrisi zaten yuklu oldugu icin
# namespace aramasına gitmeden donebilir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
   logcat -b all -c 2>/dev/null
   echo "DENEME LD_PRELOAD=libart.so"
   LD_PRELOAD=libart.so timeout 40 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
     com.android.internal.os.ZygoteInit >/tmp/lp.out 2>/tmp/lp.err
   RC=$?
   echo "  RC=$RC"
   echo "  --- stderr:"
   /bb/head -8 /tmp/lp.err | sed "s/^/    /"
   echo "  --- stdout:"
   /bb/head -8 /tmp/lp.out | sed "s/^/    /"'
