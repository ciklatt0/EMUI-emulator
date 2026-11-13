#!/system/bin/sh
# SEÇENEK 3: libicu.so ve art bagimliliklarini /data/local/tmp'ye koy,
# app_process64'i dene.
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

DST=/data/local/tmp

echo "=== 1. libicu.so ve artiklerini /data/local/tmp'ye kopyala ==="
for lib in \
  libicu.so libicuuc.so libicui18n.so libicu_jni.so \
  libart.so libartbase.so libartpalette.so \
  libnativeloader.so libnativebridge.so \
  libc.so libm.so libdl.so \
  libbase.so liblog.so libcutils.so libutils.so libbinder.so \
  libz.so liblz4.so liblzma.so libdexfile.so libjsoncpp.so \
  libprofile.so libsigchain.so libunwindstack.so libbacktrace.so \
  libtombstoned_client.so libhwlog.so libhuaweicust.so libpimutex.so \
  libc_secshared.so libc++.so libdl_android.so libstatssocket.so \
  heapprofd_client_api.so libmemleak_tracker.so libimonitor.so; do
  FOUND=""
  for SRC in /apex/com.android.art/lib64 /apex/com.android.i18n/lib64 /apex/com.android.runtime/lib64 /system/lib64 /vendor/lib64; do
    if [ -f "$SRC/$lib" ]; then
      cp "$SRC/$lib" "$DST/$lib" 2>/dev/null
      FOUND="$SRC"
      break
    fi
  done
  if [ -n "$FOUND" ]; then
    echo "  OK: $lib (from $FOUND)"
  else
    echo "  EKSIK: $lib"
  fi
done

echo ""
echo "=== 2. LD_LIBRARY_PATH ile test (60 sn) ==="
export LD_LIBRARY_PATH=/data/local/tmp
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
