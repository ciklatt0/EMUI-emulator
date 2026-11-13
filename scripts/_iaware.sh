#!/bin/bash
# Ark yolunda libiAwareSdkCore.so yukleniyor ve baska HICBIR sey
# yuklenmiyor. Huawei'nin iAware SDK'si muhtemelen Ark cekirdegini
# GOMULU tasiyor. Kontrol edelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libiAwareSdkCore.so boyutu ve DT_NEEDED ==="
A 'ls -l /system/lib64/libiAwareSdkCore.so 2>&1 | head -1
   echo "--- NEEDED:"
   /system/bin/toybox readelf -d /system/lib64/libiAwareSdkCore.so 2>/dev/null | grep NEEDED | head -15'
echo ""
echo "=== 2) icinde ark/panda sembolleri var MI ==="
A 'strings /system/lib64/libiAwareSdkCore.so 2>/dev/null | grep -iE "^libark|panda::|ark::Runtime|napi_module|JSVM" | head -15
   echo "  --- toplam ark gecen dizi: $(strings /system/lib64/libiAwareSdkCore.so 2>/dev/null | grep -ciE "ark|panda")"'
echo ""
echo "=== 3) calisan arkprobe surecinde libiAware + ark haritasi ==="
A 'P=$(getprop init.svc_debug_pid.arkprobe)
   echo "  pid=$P state=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null)"
   if [ -d /proc/$P ]; then
     echo "  --- iAwareness var mi: $(grep -c iAware /proc/$P/maps 2>/dev/null)"
     echo "  --- ark/panda eslesen:"
     grep -oE "/[a-zA-Z0-9./_+-]*(ark|panda)[a-zA-Z0-9._+-]*\.so" /proc/$P/maps 2>/dev/null | sort -u | head -10
     echo "  --- toplam benzersiz .so:"
     grep -oE "/[a-zA-Z0-9./_+-]+\.so" /proc/$P/maps 2>/dev/null | sort -u | wc -l
   fi'
echo ""
echo "=== 4) libarkruntime.so gercekten var ama yuklenmiyor MU ==="
A 'ls -l /system/lib64/ark/libarkruntime.so 2>&1 | head -1
   echo "  --- config search/permitted:"
   grep -c "lib64/ark" /linkerconfig/ld.config.txt
   echo "  --- elle cozulebiliyor MU (/data yolu, artefakt olmamasi icin):"
   cp /system/lib64/ark/libarkruntime.so /data/zr.so 2>/dev/null
   /system/bin/linker64 --list /data/zr.so 2>&1 | grep -c "=>"'
echo ""
echo "=== 5) zygote hala olmuyor MU ==="
A 'logcat -d -b all 2>/dev/null | grep -icE "SystemServer|runtime-init"
   getprop init.svc.zygote'