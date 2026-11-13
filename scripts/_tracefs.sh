#!/bin/bash
# DENEY: cekirdekte CONFIG_FTRACE / CONFIG_TRACE_FS YOK
# (kernel .config: "# CONFIG_FTRACE is not set"). Bu yuzden
# mount -t tracefs basarisiz ve:
#     F atrace@1.0-service Check failed: stat(tracefs_event_root_)
#       tracefs must be mounted at either/sys/kernel/tracing ...
#     E cutils-trace Error opening trace file: No such file or
#       directory (2)
# Yeniden derlemeden SAHTE tracefs kurup zygote'ye etkisini olcelim:
# /sys/kernel/tracing uzerine tmpfs + bos trace_marker dosyasi.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) BASLANGIC: zygote sayaci (20 sn) ==="
A 'logcat -b all -c 2>/dev/null; /bb/sleep 20; echo "  boot_progress_start sayisi = $(logcat -d -b all 2>/dev/null | grep -c boot_progress_start)"'
echo ""
echo "=== 1) sahte tracefs kur ==="
A 'mountpoint -q /sys/kernel/tracing && mount -o remount,rw /sys/kernel/tracing 2>/dev/null
   mkdir -p /sys/kernel/tracing 2>/dev/null
   mount -t tmpfs tmpfs /sys/kernel/tracing 2>&1 && echo "  tmpfs baglandi"
   mkdir -p /sys/kernel/tracing/events
   : > /sys/kernel/tracing/trace_marker
   : > /sys/kernel/tracing/trace
   ls -la /sys/kernel/tracing/ | head -6'
echo ""
echo "=== 2) atrace servisini yeniden baslat ==="
A 'setprop ctl.restart vendor.atrace-hal-1-0; /bb/sleep 4
   echo "  init.svc = [$(getprop init.svc.vendor.atrace-hal-1-0)]"
   echo "  PID = [$(getprop init.svc_debug_pid.vendor.atrace-hal-1-0)]"'
echo ""
echo "=== 3) SAHTE tracefs SONRASI: zygote sayaci (25 sn) ==="
A 'logcat -b all -c 2>/dev/null; /bb/sleep 25
   echo "  boot_progress_start sayisi = $(logcat -d -b all 2>/dev/null | grep -c boot_progress_start)"
   echo "  system_server izi = $(logcat -d -b all 2>/dev/null | grep -c "runtime-init\|SystemServer")"
   echo "  cutils-trace hatasi = $(logcat -d -b all 2>/dev/null | grep -c "Error opening trace file")"'
echo ""
echo "=== 4) zygote durumu ==="
A 'getprop init.svc.zygote; P=$(getprop init.svc_debug_pid.zygote); echo "  pid=$P state=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null)"'