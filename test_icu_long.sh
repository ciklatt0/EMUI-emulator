#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

echo "=== UZUN TEST: 45 saniye, LD_PRELOAD=libicu.so ==="
LD_PRELOAD=/data/local/tmp/libicu.so timeout 45 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1 &
ZYGOTE_PID=$!
echo "Zygote PID: $ZYGOTE_PID"

sleep 20
echo ""
echo "=== 20 sn sonra calisan surecler ==="
for d in /proc/[0-9]*; do
  E=$(readlink $d/exe 2>/dev/null)
  case "$E" in
    *system_server*) echo "SYSTEM_SERVER: $d -> $E" ;;
    *app_process*) echo "APP_PROCESS: $d -> $E" ;;
    *zygote*) echo "ZYGOTE: $d -> $E" ;;
  esac
done

echo ""
echo "=== logcat (son 30 satir, system_server/art ile ilgili) ==="
logcat -d -b all 2>/dev/null | grep -iE "system_server|zygote|runtime|artd|ZygoteInit|boot_preload" | grep -v "avc:" | tail -30

echo ""
echo "=== Zygote durum ==="
if kill -0 $ZYGOTE_PID 2>/dev/null; then
  echo "Zygote CALIYOR (PID=$ZYGOTE_PID)"
else
  echo "Zygote cikmis"
fi

kill $ZYGOTE_PID 2>/dev/null
wait $ZYGOTE_PID 2>/dev/null
echo "Zygote sonlandi"
