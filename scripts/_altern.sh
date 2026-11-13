#!/bin/bash
# BELIRLEYICI KANIT (olculdu, arac dogrulandi):
#   app_process64 10 dlopen cagriyor, 0 basarisiz, 0 libart
#   android_dlopen_ext HIC cagrilmiyor
#   persist.sys.hw.forcedark_policy=0 tek fark yaratmadi
#   zygote maps: 190 kutuphane, icinde HICBIR VM kutuphanesi
# => Bu ikili ART VM OLUSTURMUYOR. AOSP zygote bu yoldan
#    calismaz. Diger yollara bakmamiz gerekiyor.
#
# ARANANLAR:
#  1) ROM'da BASKA app_process var mi (APEX dahil)
#  2) arkinit nedir -- Huawei'nin zygote yerine gecen sey mi?
#     gercekten surec mi fork ediyor?
#  3) app_process'in --runtime-init yolu calisiyor mu
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) TUM app_process / zygote / arkinit ikilileri ==="
A 'for d in /system/bin /system/bin/* /vendor/bin /apex/*/bin; do
   b=$(basename $d 2>/dev/null)
   case "$b" in
     app_process*|*zygote*|arkinit*|*ark*) ls -l $d 2>/dev/null ;;
   esac
 done | head -20'
echo ""
echo "=== 2) /apex/com.android.art/bin TAM ==="
A 'ls -l /apex/com.android.art/bin/ 2>&1 | head -14'
echo ""
echo "=== 3) arkinit: ne oldugu ve yasayip yasamadigi ==="
A 'P=$(getprop init.svc_debug_pid.arkinit); echo "  init.svc.arkinit = [$(getprop init.svc.arkinit)]  pid=$P"
   [ -n "$P" ] && [ -d /proc/$P ] && { echo "  exe=$(readlink /proc/$P/exe)"; echo "  thr=$(ls /proc/$P/task 2>/dev/null | wc -l)"; echo "  maps=$(grep -c . /proc/$P/maps 2>/dev/null)"; echo "  cocuk sayisi: $(ls /proc/$P/task 2>/dev/null | wc -l)"; }'
echo ""
echo "=== 4) arkinit DISARIDAN calistirilirsa ne cikiyor ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   which arkinit; ls -l /system/bin/arkinit 2>&1 | head -1
   timeout 12 /system/bin/arkinit --help 2>&1 | head -15; echo "RC=$?"'
echo ""
echo "=== 5) --runtime-init yolu (system_server dogrudan) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 20 /system/bin/app_process64 -Xzygote /system/bin \
     --runtime-init com.android.server.SystemServer >/dev/null 2>/tmp/ri.err
   echo "  RC=$?"
   echo "  dlopen cagri: $(/bb/grep -c dlopen /tmp/ri.err)  libart: $(/bb/grep -c libart /tmp/ri.err)"'
echo ""
echo "=== 6) arkinit servisi tanimi (ne calistiriyor) ==="
A 'grep -rn -A 12 "^service arkinit" /system/etc/init/ /vendor/etc/init/ 2>/dev/null | head -20 | cut -c1-120'