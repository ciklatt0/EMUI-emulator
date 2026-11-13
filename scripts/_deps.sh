#!/bin/bash
# HIPOTEZ: dlopen("libart.so") BIR BAGIMLILIGI BULUNAMAYINCA
# BASARISIZ OLUYOR. app_process64 190 kutuphane yukluyor ama
# libart.so HIC yuklenmiyor; dalvikvm64 ise (libart'a DOGRUKAN
# bagli oldugu icin) sorunsuz. libart.so'nun 20 NEEDED
# bagimliliginin TAMAMI arama yollarinda mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== libart.so'nun NEEDED bagimliliklari: bulunabiliyor mu ==="
A 'NEED=$(/system/bin/toybox readelf -d /apex/com.android.art/lib64/libart.so 2>/dev/null | /bb/sed -n "s/.*Shared library: \[\(.*\)\]/\1/p")
   echo "  NEEDED sayisi: $(echo "$NEED" | wc -l)"
   echo ""
   echo "  --- ld.config [system] arama yollarinda ARAMA (find ile):"
   for n in $NEED; do
     F=$(find /system/lib64 /system_ext/lib64 /vendor/lib64 /apex -name "$n" 2>/dev/null | head -1)
     [ -n "$F" ] && echo "    VAR  $n" || echo "    YOK  $n   <<< BULUNAMADI"
   done'