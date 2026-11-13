#!/bin/bash
# YENI CERCEVE: bu ROM'da zygote/arkinit AYNI ikili
# (/system/bin/app_process64) ve VM olarak ART DEGIL ARK
# kullaniliyor:
#     service arkinit /system/bin/app_process64 -Xzygote /system/bin
#                 --zygote --nice-name=arkinit
# APEXte ikinci bir app_process YOK (stok AOSP'de com.android.art/
# bin/app_process64 vardir).
#
# => ro.ark.enable=0 yaptigimizda muhtemelen VM hic olusmuyor.
#    Bu bizim YANLIS deneyimiz olabilir. Geri alalim.
#
# ARANANLAR:
#  1) ro.ark.enable=1 yapilabiliyor mu (calisma aninda)
#  2) /system/bin/ark nedir, VM kurabiliyor mu
#  3) Ark kutuphaneleri diskte mi
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ro.ark.enable=1 yapilabilir MI ==="
A 'setprop ro.ark.enable 1 2>&1; echo "  sonuc: ro.ark.enable = [$(getprop ro.ark.enable)]"'
echo ""
echo "=== 2) /system/bin/ark --help ==="
A 'cd /; timeout 12 /system/bin/ark --help 2>&1 | head -20; echo "RC=$?"'
echo ""
echo "=== 3) Ark kutuphaneleri diskte MI ==="
A 'ls -l /system/lib64/libace_napi_ark.z.so /system/lib64/libark_debugger.z.so 2>&1 | head -3
   echo "  --- ark ile ilgili tum kutuphaneler:"
   ls /system/lib64/ | grep -iE "ark|ace_" | head -12'
echo ""
echo "=== 4) ark dizeleri: VM kurabiliyor mu ==="
A 'strings /system/bin/ark 2>/dev/null | grep -iE "zygote|classpath|boot.art|libace|runtime" | head -12'
echo ""
echo "=== 5) ONEMLI: dltrace ile ark'i calistir ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system ANDROID_RUNTIME_ROOT=/apex/com.android.art
   LD_PRELOAD=/data/dltrace.so timeout 20 /system/bin/ark --help >/dev/null 2>/tmp/ark.err
   echo "  RC=$?"
   echo "  --- ark in dlopen izleri:"
   /bb/head -25 /tmp/ark.err'