#!/bin/bash
# zygote ZygoteInit'a giriyor ve ~1-3 sn sonra SESSIZCE oluyor.
# Bu kez logcat'in TAMAMINI filtrelemeden o pencereyi yakalayalim.
# AYRICA iki crash-loop servisin neden oldugunu da olcelim:
#   atrace: tracefs must be mounted ...
#   vold:   sBlkidContext != nullptr
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) logcat tum tamponlari temizle ==="
A 'logcat -b all -c 2>/dev/null; echo temiz'
echo ""
echo "=== 1) zygote calistir, 6 sn sonra OLDUR ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zl1 >/dev/null 2>&1 &
   ZP=$!; /bb/sleep 6; kill -9 $ZP 2>/dev/null; exit 0'
echo ""
echo "=== 2) O PENCEREDE HER SEY (filtresiz, avc haric) ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -v "avc:" | tail -40'
echo ""
echo "=== 3) zygote gercekten ne kadar yasadi (bu kez PID dogrulanmis) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   T0=$(/bb/date +%s)
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zl2 >/dev/null 2>&1
   RC=$?; T1=$(/bb/date +%s)
   echo "RC=$RC sure=$((T1-T0))sn"'
echo ""
echo "=== 4) tracefs bagli MI (atrace crash'inin nedeni) ==="
A 'mountpoint -q /sys/kernel/tracing && echo "tracefs BAGLI" || echo "tracefs BAGLI DEGIL"
ls /sys/kernel/tracing/events 2>/dev/null | wc -l'
echo ""
echo "=== 5) vold crash sayisi ==="
A 'logcat -d -b crash 2>/dev/null | grep -c "sBlkidContext"; logcat -d -b all 2>/dev/null | grep -c "sBlkidContext"'