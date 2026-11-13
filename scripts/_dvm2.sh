#!/bin/bash
# ART VM ARTUK CALISIYOR. Iki engel vardi:
#  1) "boot.art component count 5, expected <= 3" -> ART imageless
#     calismaya DUSUYOR (bu bir hata degil, fallback)
#  2) core-oj.jar / core-libart.jar -> biz -Xbootclasspath'a
#     YANLIS yol (/system/framework) verdik; dogru yerleri
#     /apex/com.android.art/javalib/
# Simdi DOGRU yollarla ZygoteInit'i calistiriyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/apache-xml.jar:$J/bouncycastle.jar:$J/okhttp.jar:/system/framework/framework.jar"
   echo "  bootclasspath: $BC"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art
   export ANDROID_ART_ROOT=/apex/com.android.art
   logcat -b all -c 2>/dev/null
   timeout 30 /apex/com.android.art/bin/dalvikvm64 -Xbootclasspath:"$BC" \
     com.android.internal.os.ZygoteInit 2>&1 | /bb/head -20
   echo "  RC=$?"
   echo "  --- logcat (art/dalvikvm):"
   logcat -d -b all -v time 2>/dev/null | grep -iE "dalvikvm64|artd|AndroidRuntime|ZygoteInit|ClassNotFound|VerifyError|FATAL" | grep -v "avc:" | /bb/head -20'
echo ""
echo "=== 2) system_server fork OLDU MU ==="
A 'logcat -d -b all 2>/dev/null | grep -icE "SystemServer|runtime-init"
   echo "  --- boot_progress izleri:"
   logcat -d -b all -v time 2>/dev/null | grep -iE "boot_progress|boot_preload" | grep -v "avc:" | /bb/head -10
   echo "  --- surecler:"
   for d in /proc/[0-9]*; do E=$(readlink $d/exe 2>/dev/null); case "$E" in *dalvikvm*|*app_process*) echo "    $(basename $d) -> $E";; esac; done | /bb/head -6'