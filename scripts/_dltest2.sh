#!/bin/bash
# dltrace.so'yu /data'ya kopyalayip oradan yukle.
# DIKKAT: /bb/ hicbir namespace'e uymuyor; oradan preload edildiginde
# "libnativeloader.so not found" veriyor. /data dogru namespace'e
# dustugu icin calisir (linker64 --list /data/... kaniti).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) /data'ya kopyala ==="
A 'cp /bb/dltrace.so /data/dltrace.so 2>&1 && ls -l /data/dltrace.so'
echo ""
echo "=== 1) KONTROL: /data'dan preload edince baglanabiliyor mu ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 8 /system/bin/getprop ro.product.model 2>/tmp/p.err
   echo "  getprop RC=$?"
   echo "  --- preload hatasi var mi:"; /bb/head -5 /tmp/p.err'
echo ""
echo "=== 2) ASIL DENEY: zygote /data/dltrace.so ile ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 25 /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --start-system-server --socket-name=dt9 > /tmp/dt.out 2> /tmp/dt.err
   echo "  RC=$?"
   echo "  --- tum dlopen izleri:"
   /bb/head -60 /tmp/dt.err'
echo ""
echo "=== 3) libart icin ozel bakis ==="
A '/bb/grep -i "libart\|art\.so" /tmp/dt.err 2>/dev/null | /bb/head -10; echo "  (bos = libart hic denenmedi)"'
echo ""
echo "=== 4) toplam cagri sayisi ve ozet ==="
A 'echo "  toplam: $(/bb/grep -c dlopen /tmp/dt.err 2>/dev/null || echo 0)"
   echo "  BASARISIZ: $(/bb/grep -c BASARISIZ /tmp/dt.err 2>/dev/null || echo 0)"
   echo "  --- benzersiz yollar:"
   /bb/grep -oE "\"[a-zA-Z0-9_.+-]+\.so\"" /tmp/dt.err 2>/dev/null | sort -u | /bb/head -25'