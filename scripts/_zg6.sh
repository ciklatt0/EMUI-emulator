#!/bin/bash
# zygote ZygoteInit'a giriyor (">>>>>> START ... ZygoteInit <<<<<<")
# ve ~1-3 sn sonra SESSIZCE oluyor. Simdi logcat'in TAMAMINI
# filtrelemeden o pencerede yakalayalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) logcat tum tamponlari temizle + zorunlu etiketleri AC ==="
A 'logcat -b all -c 2>/dev/null
   setprop log.tag.artd DEBUG
   setprop log.tag.dalvikvm VERBOSE
   setprop log.tag.AndroidRuntime VERBOSE
   setprop log.tag.RuntimeInit VERBOSE
   setprop log.tag.Zygote VERBOSE
   setprop log.tag.zygote VERBOSE
   setprop log.tag.appproc VERBOSE
   setprop log.tag.art VERBOSE
   echo temiz'
echo ""
echo "=== 1) zygote calistir (stdout/stderr /dev/null, arka plan) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zl1 >/dev/null 2>&1 &
   ZP=$!; /bb/sleep 6; kill -9 $ZP 2>/dev/null; exit 0'
echo ""
echo "=== 2) O PENCEREDE HER SEY (filtresiz, sirali) ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -v "avc:" | tail -45'