#!/system/bin/sh
# TEST: LD_PRELOAD=/data/local/tmp/libart.so ile LoadNativeLibrary'nin
# namespace aramasını atlatmaya çalışıyoruz.
cd /
export ANDROID_DATA=/data ANDROID_ROOT=/system
export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
J=/apex/com.android.art/javalib
BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
mkdir -p /data/local/tmp
cp /apex/com.android.art/lib64/libart.so /data/local/tmp/libart.so 2>/dev/null
ls -l /data/local/tmp/libart.so
logcat -b all -c 2>/dev/null
echo "DENEME LD_PRELOAD=/data/local/tmp/libart.so"
LD_PRELOAD=/data/local/tmp/libart.so timeout 40 /apex/com.android.art/bin/dalvikvm64 \
  -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
  com.android.internal.os.ZygoteInit >/tmp/lp.out 2>/tmp/lp.err
RC=$?
echo "  RC=$RC"
echo "  --- stderr:"
head -8 /tmp/lp.err 2>/dev/null | sed 's/^/    /'
echo "  --- stdout:"
head -8 /tmp/lp.out 2>/dev/null | sed 's/^/    /'
echo "  --- logcat art/namespace:"
logcat -d -b all -v time 2>/dev/null | grep -iE "namespace|art::|InitNative|LoadNative" | grep -v "avc:" | head -6 | cut -c1-160
