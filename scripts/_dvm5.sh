#!/bin/bash
# ART VM CALISIYOR ve framework'u DERLIYOR (dex2oat Verification of
# android.animation.LayoutTransition... gibi satirlar). Ama
# /system/framework/arm64/boot.oat SALT-OKUNUR; ART boot image'i
# yeniden uretmeye calisiyor ve bu TCG altinde dakikalar suruyor.
#
# COZUM: boot classpath'te framework.jar'i CIKARIP onu normal
# classpath'e (-cp) tasiyoruz. Boylece ART boot image uretmek
# zorunda kalmaz -> "imageless" calisir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art
   export ANDROID_ART_ROOT=/apex/com.android.art
   logcat -b all -c 2>/dev/null
   echo "  deniyor: framework.jar -cp ile, boot image YOK"
   timeout 90 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" \
     -cp /system/framework/framework.jar \
     com.android.internal.os.ZygoteInit >/tmp/zk.out 2>/tmp/zk.err
   RC=$?
   echo "  RC=$RC  (124=90 sn yasadi, 0=cifti cikti)"
   echo "  --- stdout:"; /bb/head -25 /tmp/zk.out | sed "s/^/    /"
   echo "  --- stderr:"; /bb/head -25 /tmp/zk.err | sed "s/^/    /"'
echo ""
echo "=== ART ilerlemesi ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "dalvikvm64|dex2oat64|artd|boot_progress|boot_preload" | grep -v "avc:" | /bb/head -16 | cut -c1-170'
echo ""
echo "=== system_server / ZygoteInit ilerlemesi ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "SystemServer|runtime-init|boot_preload|ZygoteInit|ZygoteFork" | grep -v "avc:" | /bb/head -12
   echo "  --- toplam SystemServer izi: $(logcat -d -b all 2>/dev/null | grep -icE "SystemServer|runtime-init")"'