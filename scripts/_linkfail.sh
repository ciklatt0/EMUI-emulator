#!/bin/bash
# BELIRLEYICI KANIT:
#   linker64 --list /apex/com.android.art/lib64/libart.so
#     -> CANNOT LINK: library "libartpalette.so" not found
# Yani libart.so'nun bir NEEDED bagimliligi cozumlenemiyor.
# Bu, app_process64'un dlopen("libart.so") adiminin
# BASARISIZ OLMA sebebi olabilir (Huawei hata mesajini yutuyor).
# Her bagimliligin TAM yerini ve erisilebilirligini olcelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libart.so'nun 31 NEEDED bagimliliginin TAM YERLERI ==="
A 'NEED=$(/system/bin/toybox readelf -d /apex/com.android.art/lib64/libart.so 2>/dev/null | /bb/sed -n "s/.*Shared library: \[\(.*\)\]/\1/p")
   for n in $NEED; do
     echo "--- $n"
     find /system/lib64 /system_ext/lib64 /vendor/lib64 /apex -maxdepth 3 -name "$n" 2>/dev/null | head -3 | sed "s/^/      /"
   done' 2>&1 | head -80
echo ""
echo "=== 2) SANRILAN KIRILMA NOKTASI: libartpalette.so ==="
A 'echo "--- /apex/com.android.art/lib64/libartpalette.so:"
ls -l /apex/com.android.art/lib64/libartpalette.so 2>&1
echo "--- /system/lib64/libartpalette.so:"
ls -l /system/lib64/libartpalette.so 2>&1
echo "--- linker64 --list ile dogrudan deneme:"
/system/bin/linker64 --list /apex/com.android.art/lib64/libartpalette.so 2>&1 | head -4'
echo ""
echo "=== 3) [system] search.paths: /apex/com.android.art/lib64 gercekten var MI (bosluk/format) ==="
A 'awk "/^\[system\]/{s=1;next} /^\\[/{s=0} s && /search\.paths/" /linkerconfig/ld.config.txt | cut -c1-160
   echo "--- ilk 3 apex yolu (tirnak icinde mi):"
awk "/^\[system\]/{s=1;next} /^\\[/{s=0} s && /search\.paths/" /linkerconfig/ld.config.txt | tr ":" "\n" | grep -n "apex" | head -3'