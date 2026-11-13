#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

echo "=== libicu.so kopyalama ==="
cp /apex/com.android.i18n/lib64/libicu.so /data/local/tmp/libicu.so 2>&1
cp /apex/com.android.i18n/lib64/libicuuc.so /data/local/tmp/libicuuc.so 2>&1
cp /apex/com.android.i18n/lib64/libicui18n.so /data/local/tmp/libicui18n.so 2>&1
cp /apex/com.android.i18n/lib64/libicu_jni.so /data/local/tmp/libicu_jni.so 2>&1
ls -la /data/local/tmp/libicu* 2>&1

echo ""
echo "=== TEST 1: LD_PRELOAD=libicu.so ile app_process64 ==="
LD_PRELOAD=/data/local/tmp/libicu.so timeout 20 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1
echo "RC=$?"

echo ""
echo "=== TEST 2: LD_PRELOAD=libicu.so:libicuuc.so:libicui18n.so ==="
LD_PRELOAD="/data/local/tmp/libicu.so:/data/local/tmp/libicuuc.so:/data/local/tmp/libicui18n.so" timeout 20 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1
echo "RC=$?"
