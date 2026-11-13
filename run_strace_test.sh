#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
echo "=== test 1: sh -c echo ==="
/data/mini_strace -t -o /data/test1.strace -- /system/bin/sh -c "echo hello" 2>&1
echo "RC=$?"
cat /data/test1.strace
echo ""
echo "=== test 2: app_process64 -Xzygote ==="
timeout 25 /data/mini_strace -t -o /data/zyg.strace -- /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1
echo "RC=$?"
cat /data/zyg.strace
