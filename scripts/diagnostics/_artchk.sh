#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
   timeout 90 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
     com.android.internal.os.ZygoteInit >/tmp/a2.out 2>/tmp/a2.err
   echo "  RC=$?"
   echo "  --- stderr TAM:"
   /bb/cat /tmp/a2.err | /bb/head -12 | sed "s/^/    /"
   echo "  --- stdout:"
   /bb/cat /tmp/a2.out | /bb/head -12 | sed "s/^/    /"'
echo ""
echo "=== namespace hatasi KALDI MI ==="
A 'grep -c "no namespace called" /tmp/a2.err'
echo ""
echo "=== ART ilerlemesi (logcat) ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "dalvikvm64|dex2oat64|boot_preload|ZygoteInit|SystemServer" | grep -v "avc:" | /bb/head -14 | cut -c1-160'