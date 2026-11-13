#!/system/bin/sh
# SEÇENEK 3 - SON DENEME:
# 1. Tüm libart bağımlılıklarını /data/local/tmp'ye kopyala
# 2. /linkerconfig/ld.config.txt'te namespace.default.search.paths'e /data/local/tmp/ ekle
# 3. Zygote'ı init üzerinden yeniden başlat
# 4. system_server'ın çıkıp çıkmadığını kontrol et
export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art ANDROID_ART_ROOT=/apex/com.android.art

DST=/data/local/tmp

echo "=== 1. Tüm kütüphaneleri /data/local/tmp'ye kopyala ==="
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
  heapprofd_client_api.so libmemleak_tracker.so libimonitor.so \
  libziparchive.so libartdisassembler.so libart-dexlayout.so libart-compiler.so; do
  FOUND=""
  for SRC in /apex/com.android.art/lib64 /apex/com.android.i18n/lib64 /apex/com.android.runtime/lib64 /apex/com.android.os.statsd/lib64 /system/lib64 /vendor/lib64; do
    if [ -f "$SRC/$lib" ]; then
      cp "$SRC/$lib" "$DST/$lib" 2>/dev/null
      FOUND="$SRC"
      break
    fi
  done
  if [ -n "$FOUND" ]; then
    echo "  OK: $lib"
  else
    echo "  EKSIK: $lib"
  fi
done

echo ""
echo "=== 2. linker config'e /data/local/tmp ekle ==="
CONFIG=/linkerconfig/ld.config.txt
# /data/local/tmp'yi search.paths'e ekle (varsa skip et)
if ! grep -q "namespace.default.search.paths += /data/local/tmp" "$CONFIG"; then
  sed -i '/namespace.default.search.paths = \$\{LIB\}/a namespace.default.search.paths += /data/local/tmp' "$CONFIG"
  echo "  Eklendi: /data/local/tmp"
else
  echo "  Zaten mevcut"
fi

echo ""
echo "=== 3. Zygote'ı yeniden başlat ==="
stop zygote 2>/dev/null
start zygote 2>/dev/null
echo "  Zygote yeniden başlatıldı"

sleep 10

echo ""
echo "=== 4. SYSTEM_SERVER DURUMU ==="
ps -A 2>/dev/null | grep -iE "system_server|zygote|app_process"

echo ""
getprop init.svc.zygote 2>/dev/null
getprop init.svc.system_server 2>/dev/null

echo ""
echo "=== 5. Logcat: son system_server/zygote mesajları ==="
logcat -d -t 30 2>/dev/null | grep -iE "system_server|zygote|ZygoteInit|runtime|artd|boot_preload|CANNOT|failed" | grep -v "avc:" | head -20
