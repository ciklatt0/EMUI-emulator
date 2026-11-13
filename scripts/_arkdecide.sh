#!/bin/bash
# /system/lib64/ark config'e eklendi ama linker64 --list yine
# "libarkbase.so not found" diyor -- libart.so ile TAM AYNI
# asimetri. O zaman bunun da TEST ARTEFAKTI oldugunu kanitlamak
# icin ayni kutuphaneyi /data'ya kopyalayip deniyoruz.
# (libart icin bu yontem calismisti: /data yolu dogrru namespace)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /data'ya kopyala, oradan coz ==="
A 'cp /system/lib64/ark/libarkruntime.so /data/zar.so 2>&1
   echo "  /data/zar.so cozumlemesi:"
   /system/bin/linker64 --list /data/zar.so 2>&1 | head -10
   echo "  --- cozulen=$(/system/bin/linker64 --list /data/zar.so 2>&1 | grep -c "=>") hata=$(/system/bin/linker64 --list /data/zar.so 2>&1 | grep -c "CANNOT LINK")"'
echo ""
echo "=== 2) libarkbase.so libarkruntime.so'nin GERCEK bagimliligi MI ==="
A '/system/bin/toybox readelf -d /system/lib64/ark/libarkruntime.so 2>/dev/null | grep NEEDED | head -12'
echo ""
echo "=== 3) DECISIVE: zygote dltrace ile (ark acik + config duzeltilmis) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 25 /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --start-system-server --socket-name=f1 >/dev/null 2>/tmp/f1.err
   echo "  RC=$?"
   echo "  cagri=$(/bb/grep -c dlopen /tmp/f1.err) basarisiz=$(/bb/grep -c BASARISIZ /tmp/f1.err)"
   echo "  ark cagrisi=$(/bb/grep -c ark /tmp/f1.err) art cagrisi=$(/bb/grep -c libart /tmp/f1.err)"
   echo "  --- tum izler:"
   /bb/head -40 /tmp/f1.err'