#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
rm -f /data/dltrace_app.log
LD_PRELOAD=/data/dltrace.so timeout 15 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1
echo "RC=$?"
echo "=== dltrace output ==="
cat /data/dltrace.log 2>/dev/null | tail -60
