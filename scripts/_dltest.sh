#!/bin/bash
# BELIRLEYICI DENEY: app_process64'un dlopen() cagrilarini
# LD_PRELOAD ile izliyoruz. Iki olasilik kesin olarak ayrilir:
#   (a) hic dlopen cagrisi yoksa  -> app_process ART YOLUNA GIRMIYOR
#   (b) dlopen cagrisi var ama libart.so basarisizsa -> nedensellik
#       yakalayip hatayi goruruz
# DIKKAT: izleyici stderr'e yaziyor; zygote'nin stdio_to_kmsg
# ayarindan bagimsiz olarak elle calistirip dosyaya yonlendirelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) dltrace.so initramfs'e girdi MI ==="
A 'ls -l /bb/dltrace.so 2>&1 | head -1'
echo ""
echo "=== 2) ONCE KONTROL: izleyici kendi basina calisiyor mu ==="
A 'cd /; /bb/dltrace.so 2>&1 | head -3; echo "RC=$?"'
echo ""
echo "=== 3) ASIL DENEY: zygote dltrace ile ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/bb/dltrace.so timeout 20 /system/bin/app_process64 -Xzygote /system/bin \
     --zygote --start-system-server --socket-name=dt1 > /tmp/dt.out 2> /tmp/dt.err
   echo "RC=$?"
   echo "--- stderr (dlopen izleri):"
   /bb/head -40 /tmp/dt.err
   echo "--- toplam dlopen cagrisi: $(/bb/grep -c dlopen /tmp/dt.err 2>/dev/null || echo 0)"'
echo ""
echo "=== 4) libart cagrisi VARSA tam sonucu ==="
A '/bb/grep -A 1 "libart" /tmp/dt.err 2>/dev/null | /bb/head -12; echo "(bos = libart hic denenmedi)"'