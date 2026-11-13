#!/system/bin/sh
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

SRC=/apex/com.android.art/lib64
DST=/data/local/tmp

echo "=== Tum libart bagimliliklarini kopyalama ==="
for lib in \
  libartpalette.so libbacktrace.so libbase.so liblog.so liblz4.so liblzma.so \
  libnativebridge.so libnativeloader.so libsigchain.so libunwindstack.so \
  libjsoncpp.so libartbase.so libdexfile.so libprofile.so libdl_android.so \
  libicu.so libicuuc.so libicui18n.so libstatssocket.so libz.so \
  heapprofd_client_api.so libtombstoned_client.so libhwlog.so libbinder.so \
  libcutils.so libutils.so libhuaweicust.so libpimutex.so libc_secshared.so \
  libc++.so libc.so libm.so libdl.so; do
  if [ -f "$SRC/$lib" ]; then
    cp "$SRC/$lib" "$DST/$lib" 2>/dev/null
    echo "  OK: $lib"
  else
    echo "  EKSIK: $lib"
  fi
done

echo ""
echo "=== LD_PRELOAD ile test (60 sn) ==="
PRELOAD=""
for lib in \
  libartpalette.so libbacktrace.so libbase.so liblog.so liblz4.so liblzma.so \
  libnativebridge.so libnativeloader.so libsigchain.so libunwindstack.so \
  libjsoncpp.so libartbase.so libdexfile.so libprofile.so libdl_android.so \
  libicu.so libicuuc.so libicui18n.so libstatssocket.so libz.so \
  heapprofd_client_api.so libtombstoned_client.so libhwlog.so libbinder.so \
  libcutils.so libutils.so libhuaweicust.so libpimutex.so libc_secshared.so \
  libc++.so libc.so libm.so libdl.so libart.so; do
  if [ -f "$DST/$lib" ]; then
    PRELOAD="$PRELOAD:$DST/$lib"
  fi
done
PRELOAD="${PRELOAD#:}"
echo "PRELOAD=$PRELOAD"
echo ""

timeout 60 /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=f1 2>&1 &
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
