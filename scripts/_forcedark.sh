#!/bin/bash
# dltrace kesin sonuc verdi: app_process64 10 dlopen cagriyor,
# hicbiri libart icin degil, hicbiri BASARISIZ degil.
# Yani VM HIC DENENMIYOR.
#
# Bu test: persist.sys.hw.forcedark_policy (hala 1) ART yolunu
# kisadevreye aliyor olabilir mi? Ozelligi KAPATIP ayni olcumu
# TEKRAR ediyoruz -- ayni enstrument, tek degisken.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) BASLANGIC degerleri ==="
A 'for p in ro.ark.enable persist.sys.hw.forcedark_policy persist.arkinit.disable ark.restart.status; do
   echo "  $p = [$(getprop $p)]"
 done'
echo ""
echo "=== 2) BASLANGIC olcumu (degisiklik yok) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 20 /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --start-system-server --socket-name=e1 >/dev/null 2>/tmp/e1.err
   echo "  RC=$?"
   echo "  cagri: $(/bb/grep -c dlopen /tmp/e1.err)"
   echo "  basarisiz: $(/bb/grep -c BASARISIZ /tmp/e1.err)"
   echo "  libart: $(/bb/grep -c libart /tmp/e1.err)"'
echo ""
echo "=== 3) persist.sys.hw.forcedark_policy=0 YAP ==="
A 'setprop persist.sys.hw.forcedark_policy 0
   setprop persist.arkinit.disable 0
   setprop ark.restart.status 0
   /bb/sleep 3
   for p in persist.sys.hw.forcedark_policy persist.arkinit.disable ark.restart.status; do
     echo "  $p = [$(getprop $p)]"
   done'
echo ""
echo "=== 4) AYNI OLCUM (tek degisken: forcedark_policy 1->0) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 20 /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --start-system-server --socket-name=e2 >/dev/null 2>/tmp/e2.err
   echo "  RC=$?"
   echo "  cagri: $(/bb/grep -c dlopen /tmp/e2.err)"
   echo "  basarisiz: $(/bb/grep -c BASARISIZ /tmp/e2.err)"
   echo "  libart: $(/bb/grep -c libart /tmp/e2.err)"
   echo "  --- tum izler:"
   /bb/head -30 /tmp/e2.err'
echo ""
echo "=== 5) logcat: runtime tipi degisti MI ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -E "appproc|boot_progress" | grep -v "avc:" | tail -6'