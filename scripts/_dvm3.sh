#!/bin/bash
# ART boot classpath'i KABUL ETTI (Skipping non-existent gitti).
# DIKKAT (OLCUM HATASI DUZELTMESI): onceki kosuda
#   "... | /bb/head -20" sonrasi "echo RC=$?" yazdik; bu BORU
# BASAMAGINDAN sonraki $?, yani head'in kodunu verir.
# ZygoteInit'in kodu DEGILDIR. Duzeltiyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/apache-xml.jar:$J/bouncycastle.jar:$J/okhttp.jar:/system/framework/framework.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art
   export ANDROID_ART_ROOT=/apex/com.android.art
   logcat -b all -c 2>/dev/null
   timeout 40 /apex/com.android.art/bin/dalvikvm64 -Xbootclasspath:"$BC" \
     com.android.internal.os.ZygoteInit >/tmp/zi.out 2>/tmp/zi.err
   RC=$?
   echo "  GERCEK RC = $RC  (0=cifti, 124=timeout, digeri=crash)"
   echo "  --- stdout ($(wc -c < /tmp/zi.out) bayt):"
   /bb/head -25 /tmp/zi.out | sed "s/^/    /"
   echo "  --- stderr ($(wc -c < /tmp/zi.err) bayt):"
   /bb/head -25 /tmp/zi.err | sed "s/^/    /"'
echo ""
echo "=== BU PIDye ait ARTI loglari (artd/boot_progress) ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "dalvikvm64|artd|boot_preload|ZygoteInit|preload|dex2oat" | grep -v "avc:" | /bb/head -20'
echo ""
echo "=== tombstone var MI (art coktu mu) ==="
A 'logcat -d -b crash 2>/dev/null | grep -A 4 "libart" | /bb/head -12
   echo "  --- son tombstone dosyasi:"
   ls -t /data/tombstones/ 2>/dev/null | /bb/head -3'