#!/bin/bash
# "Error finding namespace of apex: no namespace called com_android_art"
# hatasi, linker'in android_dlopen_ext ICINDE olusuyor. Bizim
# dltrace.so o cagriyi ZAMANDAMGASIYLA logluyor -> hata
# olmadan hemen once hangi dlopen yapildi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
   /bb/rm -f /data/dltrace.log
   logcat -b all -c 2>/dev/null
   echo "  calistiriliyor (70 sn)..."
   LD_PRELOAD=/data/dltrace.so timeout 70 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
     com.android.internal.os.ZygoteInit >/dev/null 2>/tmp/art.err
   echo "  RC=$?"
   echo "  --- stderr:"; /bb/head -4 /tmp/art.err | sed "s/^/    /"
   echo "  --- dltrace.log ($(wc -l < /data/dltrace.log 2>/dev/null || echo 0) satir):"
   /bb/head -60 /data/dltrace.log 2>/dev/null | sed "s/^/    /"'