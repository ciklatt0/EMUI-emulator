#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art

echo "=== Mevcut zygote surecleri ==="
ps -A 2>/dev/null | grep -iE 'zygote|system_server|app_process'

echo ""
echo "=== init.svc.zygote durumu ==="
getprop init.svc.zygote 2>/dev/null

echo ""
echo "=== init.svc.system_server durumu ==="
getprop init.svc.system_server 2>/dev/null

echo ""
echo "=== Zygote soketi var mi? ==="
ls -l /dev/socket/zygote* 2>/dev/null || echo "zygote soketi yok"
ls -l /dev/socket/f1 2>/dev/null || echo "f1 soketi yok"

echo ""
echo "=== logcat kisa (son 10 satir) ==="
logcat -d -t 10 2>/dev/null | grep -v "avc:" || echo "logcat calismadi"
