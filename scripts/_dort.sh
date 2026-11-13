#!/bin/bash
# BU KOSUDA DORT DUZELTME VAR:
#  1) yeni cekirdek: CONFIG_TRACING/FTRACE acik -> tracefs mount edilebilir
#  2) ro.ark.enable=0  (build.prop katmaninda)
#  3) /data artik gecici tmpfs yerine GERCEK ext4 bolumu (vda29)
#  4) critical satirlari gercekten yorumlandi
# Her birini AYRI AYRI olcuyoruz -- varsaymiyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) TRACEFS ==="
A 'echo "  mount: $(mount | grep -c tracing)"
   mount -t tracefs tracefs /sys/kernel/tracing 2>&1 && echo "  tracefs BAGLANDI"
   echo "  olay grubu: $(ls /sys/kernel/tracing/events 2>/dev/null | wc -l)"
   echo "  trace_marker: $(ls -l /sys/kernel/tracing/trace_marker 2>&1 | head -1)"
   echo "  atrace servisi: [$(getprop init.svc.vendor.atrace-hal-1-0)]"'
echo ""
echo "=== 2) ro.ark.enable ==="
A 'echo "  ro.ark.enable = [$(getprop ro.ark.enable)]"
   echo "  persist.sys.hw.forcedark_policy = [$(getprop persist.sys.hw.forcedark_policy)]"
   echo "  --- yama gercekten tuttu mu (build.prop):"
   grep -n "^#*ro.ark.enable" /system/build.prop 2>/dev/null | head -3'
echo ""
echo "=== 3) /data GERCEK BOLUM MU ==="
A 'mount | grep " /data "
   echo "  icerik: $(ls /data/ 2>/dev/null | tr "\n" " " | cut -c1-160)"
   echo "  df:"; df -h /data 2>/dev/null | tail -1
   echo "  vold: [$(getprop init.svc.vold)]"'
echo ""
echo "=== 4) CRITICAL YORUMLANDI MI ==="
A 'echo "  init.zygote64_32.rc icinde:"
   grep -n "critical" /system/etc/init/hw/init.zygote64_32.rc 2>/dev/null | head -4 | cut -c1-110'
echo ""
echo "=== 5) ZYIGOTE ==="
A 'getprop init.svc.zygote
   P=$(getprop init.svc_debug_pid.zygote); echo "  pid=$P state=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null)"
   echo "  --- son 30 sn icinde zygote START sayisi:"
   logcat -d -b all 2>/dev/null | grep -c "START com.android.internal.os.ZygoteInit"
   echo "  --- system_server izi:"
   logcat -d -b all 2>/dev/null | grep -iE "SystemServer|runtime-init" | grep -v "avc:" | tail -3'