#!/bin/bash
# IKI BELIRLEYICI TEST:
#
# (A) AYRIK OLAN KARSILASTIRMA: linker64 --list bir kutuphaneyi
#     "/apex/com.android.art/..." yolundan yuklerken ilk
#     bagimliligini cozemiyor; ama ayni kutuphanenin KENDISI
#     "/system/lib64/..." altinda oldugunda cozuluyor mu?
#     Yol bolumu degisiyorsa sorun namespace SECIMI.
#
# (B) zygote gercekten HANGI syscall'da donuyor?
#     /proc/PID/syscall -> syscall numarasi + argumanlar.
#     Bir yerde takili kaldiysa o syscall'i goruruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== (A1) libart.so'yu /system/lib64 altina kopyalayip dene ==="
A 'cp /apex/com.android.art/lib64/libart.so /system/lib64/zz-libart.so 2>&1
   echo "  kopyalandi mi: $(ls -l /system/lib64/zz-libart.so 2>&1 | head -1)"
   echo "  --- /system/lib64/zz-libart.so ile:"
   /system/bin/linker64 --list /system/lib64/zz-libart.so 2>&1 | head -6
   echo "  --- cozulen sayisi: $(/system/bin/linker64 --list /system/lib64/zz-libart.so 2>&1 | grep -c "=>")"'
echo ""
echo "=== (A2) /data altina kopyala (baska bolum) ==="
A 'cp /apex/com.android.art/lib64/libart.so /data/zz-libart.so 2>/dev/null
   /system/bin/linker64 --list /data/zz-libart.so 2>&1 | head -4'
echo ""
echo "=== (B) zygote hangi syscall'da? (30 ornek, 200 ms) ==="
A 'for i in $(seq 0 30); do
   P=$(getprop init.svc_debug_pid.zygote 2>/dev/null)
   if [ -n "$P" ] && [ -d /proc/$P ]; then
     S=$(cat /proc/$P/syscall 2>/dev/null | awk "{print \$1}")
     W=$(cat /proc/$P/wchan 2>/dev/null)
     ST=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null)
     echo "  pid=$P syscall=$S wchan=$W state=$ST"
   fi
   /bb/sleep 0.2
 done' 2>&1 | sort | uniq -c | sort -rn | head -12