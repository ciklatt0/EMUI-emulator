#!/system/bin/sh
# DENEY: libart.so, libnativehelper.so, libnativebridge.so'yu
# /data/local/tmp'dan LD_PRELOAD ile on yukle, LoadNativeLibrary'nin
# com_android_art namespace'i aramasını atlatmaya calis.
# timeout binary'si LD_PRELOAD'dan etkilendigi icin KULLANILMIYOR;
# dalvikvm64 direkt calistiriliyor, 45sn sonra kill.
cd /
export ANDROID_DATA=/data ANDROID_ROOT=/system
export ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art
J=/apex/com.android.art/javalib
BC="$J/core-oj.jar:$J/core-libart.jar:$J/okhttp.jar:$J/bouncycastle.jar:$J/apache-xml.jar"
mkdir -p /data/local/tmp
cp /apex/com.android.art/lib64/libart.so /data/local/tmp/ 2>/dev/null
cp /apex/com.android.art/lib64/libnativehelper.so /data/local/tmp/ 2>/dev/null
cp /apex/com.android.art/lib64/libnativebridge.so /data/local/tmp/ 2>/dev/null
ls -l /data/local/tmp/libart.so /data/local/tmp/libnativehelper.so /data/local/tmp/libnativebridge.so 2>&1
logcat -b all -c 2>/dev/null
echo "DENEY LD_PRELOAD=art+nativehelper+nativebridge (direkt calisma)"
LD_PRELOAD=/data/local/tmp/libart.so:/data/local/tmp/libnativehelper.so:/data/local/tmp/libnativebridge.so \
  /apex/com.android.art/bin/dalvikvm64 \
  -Xbootclasspath:"$BC" -cp /system/framework/framework.jar \
  com.android.internal.os.ZygoteInit >/tmp/lp3.out 2>/tmp/lp3.err &
DPID=$!
sleep 45
kill $DPID 2>/dev/null
wait $DPID 2>/dev/null
RC=$?
echo "  RC=$RC  (0=cifti, 128+sig=sinyalle sonlandi, 143=SIGTERM)"
echo "  --- stderr:"
head -10 /tmp/lp3.err 2>/dev/null | sed 's/^/    /'
echo "  --- stdout:"
head -10 /tmp/lp3.out 2>/dev/null | sed 's/^/    /'
echo "  --- logcat art/namespace:"
logcat -d -b all -v time 2>/dev/null | grep -iE "namespace|nativeloader|InitNative|LoadNative|setting boot|no namespace" | grep -v "avc:" | head -8 | cut -c1-160
