#!/bin/bash
# ASILI PARCA BULUNDU:
#     setenv ARK_RUNTIME libarkruntime.so
#     on property:ro.ark.enable=1 -> start arkinit
# Elle calistirdigimiz zygote'lerde ARK_RUNTIME YOKTU, o yuzden
# hep "runtime = 0" (ART yolu) cikiyordu. Gercek arkinit servisi
# init tarafindan bu degiskenle baslatiliyor ve simdi "running".
# Onun HARITASINI ve ORTAMINI okuyalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) arkinit SERVISI gercekten yasiyor mu ==="
A 'P=$(getprop init.svc_debug_pid.arkinit)
   echo "  init.svc.arkinit=[$(getprop init.svc.arkinit)] pid=$P"
   if [ -n "$P" ] && [ -d /proc/$P ]; then
     echo "  exe=$(readlink /proc/$P/exe)"
     echo "  state=$(awk "{print \$3}" /proc/$P/stat) thr=$(ls /proc/$P/task 2>/dev/null | wc -l)"
     echo "  --- ORTAM:"
     tr "\0" "\n" < /proc/$P/environ 2>/dev/null | grep -E "ARK|ANDROID" | sed "s/^/    /"
     echo "  --- HARiTADA ARK VAR MI:"
     grep -oE "/[a-zA-Z0-9./_]*lib[a-z_]*ark[a-zA-Z0-9._]*\.so" /proc/$P/maps 2>/dev/null | sort -u | sed "s/^/    /" | head -10
     echo "  --- libart: $(grep -c libart /proc/$P/maps 2>/dev/null)"
   else
     echo "  arkinit YASIYOR DEGIL"
   fi'
echo ""
echo "=== 2) ARK_RUNTIME degerinin dogru oldugunu dogrula (config) ==="
A 'grep -n "lib64/ark" /linkerconfig/ld.config.txt | head -3
   echo "  --- libarkruntime.so diskte:"
   ls -l /system/lib64/ark/libarkruntime.so 2>&1 | head -1'
echo ""
echo "=== 3) ARK_RUNTIME ILE ELLE calistir (gercek ortami taklit et) ==="
A 'logcat -b all -c 2>/dev/null
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   ARK_RUNTIME=libarkruntime.so LD_PRELOAD=/data/dltrace.so timeout 25 /system/bin/app_process64 \
     -Xzygote /system/bin --zygote --nice-name=zygote64 --socket-name=ark >/dev/null 2>/tmp/h1.err
   echo "  RC=$?"
   echo "  cagri=$(/bb/grep -c dlopen /tmp/h1.err) ark=$(/bb/grep -c ark /tmp/h1.err) basarisiz=$(/bb/grep -c BASARISIZ /tmp/h1.err)"
   echo "  --- ark izleri:"
   /bb/grep -i ark /tmp/h1.err | /bb/head -12
   echo "  --- logcat runtime tipi:"
   logcat -d -b all -v time 2>/dev/null | grep -iE "appproc|boot_progress|ark" | grep -v "avc:" | head -8'