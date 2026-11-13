#!/bin/bash
# SON REAL YOL: app_process64 VM OLUSTURMUYOR, ama
# /apex/com.android.art/bin/dalvikvm64 ART'yi GERCEKTEN
# yukluyor (4 map satiri -- olculdu). Dalvikvm de zygote
# sinifini calistirabilir (AOSP'de de boyle kullanilir):
#     dalvikvm -cp /system/framework/... com.android.internal.os.ZygoteInit
# Boylece bozuk app_process'i ATLAYIP dogrudan VM + framework
# yuklemeyi deniyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) dalvikvm64 gercekten ART yukluyor MU (kontrol) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so /apex/com.android.art/bin/dalvikvm64 -version >/dev/null 2>/tmp/dv.err &
   P=$!; /bb/sleep 3
   if [ -d /proc/$P ]; then
     echo "  libart.so  = $(grep -c libart.so /proc/$P/maps)"
     echo "  libartbase = $(grep -c libartbase /proc/$P/maps)"
   fi
   kill -9 $P 2>/dev/null
   echo "  --- dlopen izleri:"
   /bb/head -15 /tmp/dv.err'
echo ""
echo "=== 2) zygote sinifini framework uzerinden calistir ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   export ANDROID_TZDATA_ROOT=/apex/com.android.tzdata
   export ANDROID_IOTA_ROOT=/apex/com.android.iota
   timeout 25 /apex/com.android.art/bin/dalvikvm64 \
     -cp /system/framework/framework.jar \
     com.android.internal.os.ZygoteInit 2>&1 | /bb/head -20
   echo "  RC=$?"'
echo ""
echo "=== 3) bootclasspath ile (Android 12 dogru yolu) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   logcat -b all -c 2>/dev/null
   timeout 25 /apex/com.android.art/bin/dalvikvm64 \
     -Xbootclasspath:/system/framework/core-oj.jar:/system/framework/core-libart.jar:/system/framework/framework.jar \
     com.android.internal.os.ZygoteInit 2>&1 | /bb/head -15
   echo "  RC=$?"
   echo "  --- logcat:"
   logcat -d -b all -v time 2>/dev/null | grep -iE "ZygoteInit|artd|dalvik|ART|ClassNotFound|VerifyError" | grep -v "avc:" | /bb/head -12'