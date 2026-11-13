#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

echo "=== libicu.so kopyalama ==="
cp /apex/com.android.i18n/lib64/libicu.so /data/local/tmp/libicu.so 2>&1
cp /apex/com.android.i18n/lib64/libicuuc.so /data/local/tmp/libicuuc.so 2>&1
cp /apex/com.android.i18n/lib64/libicui18n.so /data/local/tmp/libicui18n.so 2>&1
ls -la /data/local/tmp/libicu* 2>&1

echo ""
echo "=== TEST: LD_PRELOAD=libicu.so ile app_process64 (60 sn) ==="
LD_PRELOAD=/data/local/tmp/libicu.so timeout 60 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1 &
ZY_PID=$!
echo "Zygote PID: $ZY_PID"

sleep 35
echo ""
echo "=== CALISAN SURECLER ==="
ps -A 2>/dev/null | grep -iE "system_server|zygote|app_process"

echo ""
echo "=== INIT SERVIS DURUMLARI ==="
getprop init.svc.zygote 2>/dev/null
getprop init.svc.system_server 2>/dev/null

echo ""
echo "=== ZYGOTE HENUDE CALISIYOR MU? ==="
if kill -0 $ZY_PID 2>/dev/null; then
  echo "EVET (PID=$ZY_PID)"
else
  echo "HAYIR (cikmis)"
fi

kill $ZY_PID 2>/dev/null
wait $ZY_PID 2>/dev/null
echo "Zygote sonlandi"
