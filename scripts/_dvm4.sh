#!/bin/bash
# ART VM CALISIYOR (40 sn yasadi, RC=124) ve dex2oat calisiyor.
# ENGEL: boot.art icindeki kayitli SIRA ile verdigimiz sira
# FARKLI:
#   oat      : core-oj, core-libart, okhttp,       bouncycastle, apache-xml
#   verdigimiz: core-oj, core-libart, apache-xml,   bouncycastle, okhttp
# AYNI 5 dosya, farkli sira. Art bunu "Failed to match oat boot
# class path" diye reddediyor.
# DIKKAT: onceki boot.art hatasi da ("component count 5,
# expected <= 3") bu siranin yanlis olmasindan kaynaklanabilir.
# Simdi oat'in bekledigi SIRAYI veriyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   # SIRALI yer: oat kaydi: core-oj, core-libart, okhttp, bouncycastle, apache-xml
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   CP="$BC:/system/framework/framework.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art
   export ANDROID_ART_ROOT=/apex/com.android.art
   logcat -b all -c 2>/dev/null
   timeout 60 /apex/com.android.art/bin/dalvikvm64 -Xbootclasspath:"$CP" \
     com.android.internal.os.ZygoteInit >/tmp/zj.out 2>/tmp/zj.err
   RC=$?
   echo "  RC=$RC  (124=timeout, yani 60 sn yasadi)"
   echo "  --- stdout:"; /bb/head -20 /tmp/zj.out | sed "s/^/    /"
   echo "  --- stderr:"; /bb/head -20 /tmp/zj.err | sed "s/^/    /"
   echo "  --- ART/dex2oat loglari:"
   logcat -d -b all -v time 2>/dev/null | grep -iE "dalvikvm64|dex2oat64|artd" | grep -v "avc:" | /bb/head -12 | cut -c1-190'
echo ""
echo "=== SIRA DUZELDI MI ==="
A 'logcat -d -b all 2>/dev/null | grep -icE "Failed to match oat boot class path"
   echo "  --- boot_preload / system_server:"
   logcat -d -b all 2>/dev/null | grep -iE "boot_preload|SystemServer|runtime-init" | grep -v "avc:" | /bb/head -8'