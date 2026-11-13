#!/bin/bash
# IKI OLCUMU ESZAMANLI AL:
#   getprop ro.ark.enable  == 0  (yamamiz tutmus)
#   logcat "Runtime type: ark runtime = 0"
# Ikisi ayni anda bakilirsa aradaki nedensellik kurulur.
# Simdiye kadar hep ayri ayri baktik; hiç eslestirmedik.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) eszamanli: once ozellik, sonra 25 sn log ==="
A 'logcat -b all -c 2>/dev/null
   echo "  [T0] ro.ark.enable = [$(getprop ro.ark.enable)]  persist.sys.hw.forcedark_policy = [$(getprop persist.sys.hw.forcedark_policy)]"
   /bb/sleep 25
   echo "  [T1] ro.ark.enable = [$(getprop ro.ark.enable)]"
   echo "  --- bu pencerede appproc gormesi:"
   logcat -d -b all -v time 2>/dev/null | grep "appproc" | grep -v "avc:" | head -10'
echo ""
echo "=== 2) app_process64 hangi ozellige bakiyor? (strings) ==="
A 'strings /system/bin/app_process64 2>/dev/null | grep -E "^(ro|persist)\." | head -10
   echo "  --- ARK_RUNTIME cevresindeki digerleri:"
   strings /system/bin/app_process64 2>/dev/null | grep -B 2 -A 2 "ARK_RUNTIME" | head -8'
echo ""
echo "=== 3) zygote, ART yolunda oldugunda libart YUKLENMIYOR muydu? ==="
A 'echo "  simdi kontrol: zygote PID basina libart"
   for i in 1 2 3 4 5 6; do
     P=$(getprop init.svc_debug_pid.zygote 2>/dev/null)
     if [ -n "$P" ] && [ -d /proc/$P ] && [ "$(grep -c . /proc/$P/maps 2>/dev/null)" -gt 300 ]; then
       echo "    pid=$P libart=$(grep -c libart /proc/$P/maps 2>/dev/null) libandroid_runtime=$(grep -c libandroid_runtime /proc/$P/maps 2>/dev/null)"
     fi
     /bb/sleep 1
   done'