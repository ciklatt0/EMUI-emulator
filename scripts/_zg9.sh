#!/bin/bash
# IKI "service zygote" tanimi var. Init tekrarli tanimayi REDDEDER
# (birini yok sayar). Hangisi yasayacak onu olcmek lazim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) kernel'de CONFIG_COMPAT var MI (32-bit calisabilir mi) ==="
A 'zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_COMPAT|CONFIG_COMPAT_BRK|CONFIG_32BIT" || echo "(config.gz yok)"'
echo ""
echo "=== 2) app_process (32-bit) ELF sinifi ==="
A '/system/bin/toybox file /system/bin/app_process /system/bin/app_process64 2>&1 | head -4'
echo ""
echo "=== 3) init tekrarli servis uyarisi verdi MI ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "redefin|overrid|duplicate|already.*defined|zygote32|zygote64" | grep -v "avc:" | head -6; echo "(bos ise uyari yok)"'
echo ""
echo "=== 4) CALISAN zygote SURECI hangi ikili? (exe kaniti) ==="
A 'logcat -b all -c 2>/dev/null
   P=$(/bb/pidof zygote64 2>/dev/null; /bb/pidof app_process64 2>/dev/null; /bb/pidof app_process 2>/dev/null)
   echo "pidof=[$P]"
   for p in $P; do echo "  pid=$p exe=$(ls -l /proc/$p/exe 2>/dev/null | sed "s/.*-> //")"; done
   for i in 1 2 3 4 5 6 7 8; do
     P=$(/bb/pidof app_process64 2>/dev/null)
     if [ -n "$P" ]; then echo "  yakalandi: pid=$P exe=$(ls -l /proc/$P/exe 2>/dev/null | sed "s/.*-> //") thr=$(ls /proc/$P/task 2>/dev/null | wc -l) libart=$(grep -c libart /proc/$P/maps 2>/dev/null)"; break; fi
     /bb/sleep 1
   done'
echo ""
echo "=== 5) ZYIGOTE PENCERESI: logcat TAMAMEN BOS MU ==="
A 'logcat -b all -c 2>/dev/null
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zp9 >/dev/null 2>&1 &
   ZP=$!; /bb/sleep 8; kill -9 $ZP 2>/dev/null
   echo "--- 8 sn icinde zygote PID $ZP den izler:"
   logcat -d -b all -v time 2>/dev/null | tail -18'