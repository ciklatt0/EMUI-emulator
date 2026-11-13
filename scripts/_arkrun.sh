#!/bin/bash
# ARK YOLUNU ELLE, SERVISIN TUM ORTAMIYLA calistiriyoruz.
# init baslatilan servislere LD_PRELOAD ekleyemiyoruz (rclog'a
# dokunmak gerekir) -- ama init'in servis tanimini elle TAKLIT
# edebiliriz:
#     setenv ARK_RUNTIME libarkruntime.so
#     ANDROID_RUNTIME_ROOT/TZDATA_ROOT/IOTA_ROOT
#     --nice-name=zygote64 --socket-name=ark
# Onceden sadece ARK_RUNTIME vermistik ve sonuc init'in
# sureclerinin gurultusune karisti; bu kez arkinit'i durdurup
# PID'mizi kimliklendirerek olcuyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) gurultuyu kes: arkinit ve zygote'yi durdur ==="
A 'setprop ctl.stop arkinit; setprop ctl.stop zygote; /bb/sleep 3
   echo "  arkinit=[$(getprop init.svc.arkinit)] zygote=[$(getprop init.svc.zygote)]"'
echo ""
echo "=== 2) ARK YOLU: tam ortam + dltrace ==="
A 'logcat -b all -c 2>/dev/null
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   export ANDROID_RUNTIME_ROOT=/apex/com.android.art
   export ANDROID_TZDATA_ROOT=/apex/com.android.tzdata
   export ANDROID_IOTA_ROOT=/apex/com.android.iota
   export ARK_RUNTIME=libarkruntime.so
   LD_PRELOAD=/data/dltrace.so /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --nice-name=zygote64 --socket-name=ark >/tmp/i.out 2>/tmp/i.err &
   ZP=$!
   echo "  PID=$ZP"
   /bb/sleep 20
   if [ -d /proc/$ZP ]; then
     echo "  hala yasiyor: state=$(awk "{print \$3}" /proc/$ZP/stat) thr=$(ls /proc/$ZP/task 2>/dev/null | wc -l)"
     echo "  libark=$(grep -c libark /proc/$ZP/maps 2>/dev/null) libart=$(grep -c libart /proc/$ZP/maps 2>/dev/null)"
     echo "  haritadaki ark kutuphaneleri:"
     grep -oE "/[a-zA-Z0-9./_]*lib[a-z_]*ark[a-zA-Z0-9._]*\.so" /proc/$ZP/maps 2>/dev/null | sort -u | head -10
     kill -9 $ZP 2>/dev/null
   else
     echo "  PID $ZP 20 sn icinde oldu"
   fi
   wait $ZP 2>/dev/null; echo "  RC=$?"'
echo ""
echo "=== 3) dltrace ciktisi (ARK YOLU) ==="
A '/bb/head -45 /tmp/i.err'
echo ""
echo "=== 4) bu PIDye ait logcat ==="
A 'logcat -d -b all -v time 2>/dev/null | tail -20'