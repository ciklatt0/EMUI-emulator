#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

echo "=== TEST: LD_PRELOAD=libnativeloader.so:libart.so:libicu.so ==="
LD_PRELOAD="/apex/com.android.art/lib64/libnativeloader.so:/apex/com.android.art/lib64/libart.so:/apex/com.android.i18n/lib64/libicu.so" timeout 30 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1
echo "RC=$?"
