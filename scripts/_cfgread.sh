#!/bin/bash
# link.default VE link.public yazili (1882/1883) ama hata suruyor.
# Iki olasilik:
#  (a) linker config'i OKUMUYOR (bizim config reddediliyor,
#      dahili varsayilana dustugu icin com_android_art yok)
#  (b) config okunuyor ama namespace arama yolu baska
# AYIRT ETME: BILEREK BOZUK bir config verip linker'in
# "config hatasi" dedigini gorelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'J=/apex/com.android.art/javalib
   BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

   echo "=== (1) BOZUK config: olmayan namespace referansi ==="
   printf "[system]\nnamespace.default.search.paths = /system/lib64\nlink.default = HICBOYLEBIRAYNAVAR\n" > /data/bad.conf
   LD_CONFIG_FILE=/data/bad.conf timeout 12 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/head -4
   echo "  RC=$?"

   echo ""
   echo "=== (2) link.public SATIRINI OLMAYAN config ==="
   printf "[system]\nnamespace.default.search.paths = /system/lib64\n" > /data/nopub.conf
   LD_CONFIG_FILE=/data/nopub.conf timeout 12 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/head -4
   echo "  RC=$?"

   echo ""
   echo "=== (3) canli config, link.public SATIRINI SIL ==="
   /bb/grep -v "^link.public" /linkerconfig/ld.config.txt > /data/nopub2.conf
   LD_CONFIG_FILE=/data/nopub2.conf timeout 12 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/head -4
   echo "  RC=$?"

   echo ""
   echo "=== (4) canli config TAMAMEN ==="
   LD_CONFIG_FILE=/linkerconfig/ld.config.txt timeout 12 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:"$BC" -cp /system/framework/framework.jar com.android.internal.os.ZygoteInit 2>&1 | /bb/head -4
   echo "  RC=$?"'