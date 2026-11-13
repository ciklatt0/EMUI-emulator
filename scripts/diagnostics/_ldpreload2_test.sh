#!/system/bin/sh
# TEST: libnativeloader.so + libart.so'yu /data'dan LD_PRELOAD ile
# on yukle. Linker bunlari /data altindan cozunce system namespace'i
# kullanir, com_android_art namespace'e gerek kalmaz.
cd /
export ANDROID_DATA=/data ANDROID_ROOT=/system
export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
J=/apex/com.android.art/javalib
BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
mkdir -p /data/local/tmp
cp /apex/com.android.art/lib64/libart.so /data/local/tmp/libart.so 2>/dev/null
cp /apex/com.android.art/lib64/libnativeloader.so /data/local/tmp/libnativeloader.so 2>/dev/null
ls -l /data/local/tmp/libart.so /data/local/tmp/libnativeloader.so 2>&1
logcat -b all -c 2>/dev/null
echo "DENEME LD_PRELOAD=libnativeloader.so:libart.so"
LD_PRELOAD=/data/local/tmp/libnativeloader.so:/data/local/tmp/libart.so timeout 50 /apex/com.android.art/bin/dalvikvm64 \
  -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
  com.android.internal.os.ZygoteInit >/tmp/lp2.out 2>/tmp/lp2.err
RC=$?
echo "  RC=$RC  (124=50sn calisti, 0=cifti cikti)"
echo "  --- stderr:"
head -10 /tmp/lp2.err 2>/dev/null | sed 's/^/    /'
echo "  --- stdout:"
head -10 /tmp/lp2.out 2>/dev/null | sed 's/^/    /'
echo "  --- logcat art/namespace:"
logcat -d -b all -v time 2>/dev/null | grep -iE "namespace|nativeloader|InitNative|LoadNative|setting boot" | grep -v "avc:" | head -8 | cut -c1-160
