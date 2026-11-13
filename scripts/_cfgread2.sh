#!/bin/bash
# DIKKAT (OLCUM HATASI DUZELTMESI): onceki testte
#   "... | head -4 ; echo RC=$?" yazdik -> RC, BORU BASAMAGINDAN
# sonraki $? yani head/timeout kodu. Ayrica timeout 12 cok kisaydi:
# "Error finding namespace" ~30 sn sonra cikiyor.
# Simdi: 70 sn, stderr dosyaya, gercek RC.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

   run() {
     NAME="$1"; CFG="$2"
     /bb/rm -f /tmp/r.err
     if [ -n "$CFG" ]; then export LD_CONFIG_FILE="$CFG"; else unset LD_CONFIG_FILE; fi
     timeout 70 /apex/com.android.art/bin/dalvikvm64 \
       -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
       com.android.internal.os.ZygoteInit >/dev/null 2>/tmp/r.err
     RC=$?
     unset LD_CONFIG_FILE
     ERR=$(/bb/head -2 /tmp/r.err | /bb/tr "\n" " | " | cut -c1-110)
     echo "  [$NAME] RC=$RC"
     echo "      stderr: ${ERR:-(bos)}"
   }

   run "varsayilan"        ""
   run "canli config"      "/linkerconfig/ld.config.txt"
   /bb/grep -v "^link.public" /linkerconfig/ld.config.txt > /data/nopub2.conf
   run "link.public YOK"   "/data/nopub2.conf"
   /bb/grep -v "^link.default" /linkerconfig/ld.config.txt > /data/nodef2.conf
   run "link.default YOK"  "/data/nodef2.conf"'