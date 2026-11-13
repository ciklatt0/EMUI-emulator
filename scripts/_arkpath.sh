#!/bin/bash
# logcat iki farkli surec gosteriyor:
#   Runtime type: ark runtime = 0  -> boot_progress_start basip oluyor
#   Runtime type: ark runtime = 1  -> sadece START basip oluyor
# Bunlar zygote ve arkinit olabilir (ikisi de ayni ikili).
# ARK YOLUNU (runtime = 1) IZLEMEK gerekiyor.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) arkinit servis taniminin TAMAMI ==="
A 'awk "/^service arkinit/,/^}/" /system/etc/init/hw/init.arkinit.rc 2>/dev/null | head -30 | cut -c1-110'
echo ""
echo "=== 2) arkinit calisiyor MU, kim baslatiyor ==="
A 'echo "  init.svc.arkinit = [$(getprop init.svc.arkinit)]"
   echo "  pid = [$(getprop init.svc_debug_pid.arkinit)]"
   echo "  --- logcat arkinit:"
   logcat -d -b all 2>/dev/null | grep -i arkinit | grep -v "avc:" | tail -8'
echo ""
echo "=== 3) ELLE calistirilan zygote hangi yolu aliyor ==="
A 'logcat -b all -c 2>/dev/null
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   timeout 15 /system/bin/app_process64 -Xzygote /system/bin --zygote --nice-name=arkinit \
     >/dev/null 2>&1
   echo "  --- bu calistirmanin logu:"
   logcat -d -b all -v time 2>/dev/null | grep -iE "appproc|ark|boot_progress|START" | grep -v "avc:" | head -10'
echo ""
echo "=== 4) --nice-name=arkinit farki yaratiyor MU ==="
A 'logcat -b all -c 2>/dev/null
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 20 /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --nice-name=arkinit >/dev/null 2>/tmp/g1.err
   echo "  cagri=$(/bb/grep -c dlopen /tmp/g1.err) ark=$(/bb/grep -c ark /tmp/g1.err)"
   /bb/grep -iE "ark|art" /tmp/g1.err | /bb/head -8
   echo "  --- logcat:"
   logcat -d -b all -v time 2>/dev/null | grep -iE "appproc|boot_progress" | grep -v "avc:" | head -6'
echo ""
echo "=== 5) Ark icin gereken .abc dosyalari erisilebilir MI ==="
A 'ls -l /system/framework/framework.abc /system/framework/core-oj.abc 2>&1 | head -3
   echo "  --- pandastdlib/arkstdlib.abc (ark varsayilani) YOK:"
   ls -l /system/pandastdlib/arkstdlib.abc 2>&1 | head -1'