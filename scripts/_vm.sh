#!/bin/bash
# app_process64 HICBIR ZAMAN libart.so yuklemiyor (8 noktada
# olculdu, ayrica init'in baslattigi zygote'de de).
# Ama "START com.android.internal.os.ZygoteInit" basiyor.
# VE "Runtime type: ark runtime = 0" diyor.
# Yani Huawei ART'nin YERINE baska bir VM kullaniyor.
# HANGI kutuphaneyi yukluyor?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) app_process64 icindeki VM/ark dizileri ==="
A 'strings /system/bin/app_process64 2>/dev/null | grep -iE "ark|dvm|libart|runtime type|dlopen" | head -20'
echo ""
echo "=== 2) sistemde ark VM kutuphaneleri var MI ==="
A 'ls /system/lib64/ 2>/dev/null | grep -iE "ark|vm|dvm" | head -10
   echo "--- apex:"
   ls /apex/com.android.art/lib64/ 2>/dev/null | grep -iE "ark|vm|dvm" | head -10
   echo "--- /system/bin ark:"
   ls /system/bin/ 2>/dev/null | grep -iE "ark|dvm|zygote" | head -10'
echo ""
echo "=== 3) ark ile ilgili ozellikler ==="
A 'getprop | grep -iE "ark" | head -20'
echo ""
echo "=== 4) calisan zygote: TUM yuklenen kutuphanelerde ark/VM ara ==="
A 'logcat -b all -c 2>/dev/null
   P=""
   i=0
   while [ $i -lt 20 ]; do
     Q=$(getprop init.svc_debug_pid.zygote 2>/dev/null)
     [ -n "$Q" ] && [ -d /proc/$Q ] && [ -n "$(readlink /proc/$Q/exe 2>/dev/null)" ] && { P=$Q; break; }
     i=$((i+1)); /bb/sleep 0.3
   done
   if [ -n "$P" ]; then
     echo "  zygote pid=$P"
     grep -oE "/[a-zA-Z0-9._/+-]+\.so" /proc/$P/maps 2>/dev/null | sort -u > /tmp/zs.txt
     echo "  toplam benzersiz kutuphane: $(wc -l < /tmp/zs.txt)"
     echo "  ark/vm/dvm eslesen:"
     grep -iE "ark|vm|dvm|jvm" /tmp/zs.txt | head -10
     echo "  --- apex art lib64 eslesenleri:"
     grep "com.android.art" /tmp/zs.txt | head -10
   else echo "  zygote yakalanamadi"; fi'