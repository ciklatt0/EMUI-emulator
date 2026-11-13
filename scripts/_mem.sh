#!/bin/bash
# BELLEK DENEYI: ayni build, tek degisken -m 4096 -> 8192.
# Hipotez: Ark VM 4 GB'ta tahsis EDEMIYOR olabilir; basarisiz
# tahsis sessizce sureci status 0 ile cikartiyor olabilir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) konukta toplam bellek ==="
A '/bb/grep -E "MemTotal|MemAvailable" /proc/meminfo'
echo ""
echo "=== 2) zygote ne kadar kullanuyor / yasiyor mu ==="
A 'P=$(getprop init.svc_debug_pid.zygote)
   echo "  pid=$P state=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null)"
   if [ -n "$P" ] && [ -d /proc/$P ]; then
     grep -E "VmRSS|VmSize|VmPeak" /proc/$P/status 2>/dev/null | sed "s/^/    /"
     echo "    maps=$(grep -c . /proc/$P/maps 2>/dev/null) libark=$(grep -c libark /proc/$P/maps 2>/dev/null) libart=$(grep -c libart /proc/$P/maps 2>/dev/null)"
   fi
   echo "  --- arkprobe (VM denemesi, olcek icin):"
   setprop ctl.start arkprobe; /bb/sleep 12
   Q=$(getprop init.svc_debug_pid.arkprobe)
   echo "    pid=$Q state=$(awk "{print \$3}" /proc/$Q/stat 2>/dev/null)"
   [ -n "$Q" ] && [ -d /proc/$Q ] && grep -E "VmRSS|VmPeak" /proc/$Q/status 2>/dev/null | sed "s/^/      /"'
echo ""
echo "=== 3) arkprobe dlopen izi (bellek degisti, sonuc degisti mi) ==="
A 'rm -f /data/dltrace.log
   setprop ctl.stop arkprobe 2>/dev/null; /bb/sleep 1
   setprop ctl.start arkprobe; /bb/sleep 14
   if [ -f /data/dltrace.log ]; then
     echo "  satirlar: $(wc -l < /data/dltrace.log)"
     /bb/head -25 /data/dltrace.log | sed "s/^/    /"
   else echo "  LOG YOK"; fi'
echo ""
echo "=== 4) zygote yine oluyor MU ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -icE "SystemServer|runtime-init"
   logcat -d -b all -v time 2>/dev/null | grep -E "appproc|boot_progress" | grep -v "avc:" | tail -6'