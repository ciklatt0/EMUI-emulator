#!/bin/bash
# ARK YOLU DENEMESI: iki duzeltme birlikte uygulandi
#  1) /system/lib64/ark linker config'e eklendi (search+permitted)
#  2) ro.ark.enable yaması GERI ALINDI (firmware degeri 1)
# Soru: Ark VM simdi kuruluyor mu, zygote yasiyor mu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ro.ark.enable gercekten 1 MI ==="
A 'getprop ro.ark.enable; echo "  build.prop satiri:"; grep -n "^ro.ark.enable" /system/build.prop 2>/dev/null | head -2'
echo ""
echo "=== 2) /system/lib64/ark config icinde MI ==="
A 'echo "  config sayisi: $(grep -c "lib64/ark" /linkerconfig/ld.config.txt)"
   grep -n "lib64/ark" /linkerconfig/ld.config.txt | head -4
   echo "  --- linker cozebiliyor mu:"
   /system/bin/linker64 --list /system/lib64/ark/libarkruntime.so 2>&1 | head -6'
echo ""
echo "=== 3) ARK KUTUPHANELERI COZULUYOR MU ==="
A 'for L in libarkruntime.so libarkbase.so libarkfile.so libarkcompiler.so libark_jsruntime.so; do
   P=/system/lib64/ark/$L
   [ -f "$P" ] || continue
   N=$(/system/bin/linker64 --list "$P" 2>&1 | grep -c "=>")
   E=$(/system/bin/linker64 --list "$P" 2>&1 | grep -c "CANNOT LINK")
   echo "  $L: cozulen=$N hata=$E"
 done'
echo ""
echo "=== 4) ZYIGOTE ==="
A 'getprop init.svc.zygote
   P=$(getprop init.svc_debug_pid.zygote); echo "  pid=$P state=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null) thr=$(ls /proc/$P/task 2>/dev/null | wc -l)"
   echo "  libart=$(grep -c libart /proc/$P/maps 2>/dev/null) libark=$(grep -c libark /proc/$P/maps 2>/dev/null)"'
echo ""
echo "=== 5) logcat: zygote penceresi ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "appproc|ark|boot_progress|ZygoteInit" | grep -v "avc:" | tail -14'
echo ""
echo "=== 6) system_server ==="
A 'logcat -d -b all 2>/dev/null | grep -icE "SystemServer|runtime-init"
   for d in /proc/[0-9]*; do E=$(readlink $d/exe 2>/dev/null); case "$E" in *app_process*) echo "  $(basename $d) -> $E";; esac; done | head -5'