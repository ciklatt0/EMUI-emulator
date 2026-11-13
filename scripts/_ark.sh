#!/bin/bash
# zygote 3 sn yasayip CIKIS KODU 0 ile cikiyor. ZygoteInit::start()
# erken donuyor. Uc olasilik var; olcum araciyla ayirt edecegiz:
#   a) Ark runtime (Huawei Ozel ART fork) on kosulu eksik
#   b) ANDROID_SOCKET_zygote (init soketi) gerekli
#   c) preload sessizce vazgeciyor
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) Ark runtime ozellikleri ==="
A 'getprop | grep -iE "ark|huawei.*runtime|ohos" | head -15'
echo ""
echo "=== 2) app_process'un bekledigi ek ortam degiskenleri ==="
A 'strings /system/bin/app_process64 2>/dev/null | grep -E "^ANDROID_[A-Z_]+$" | sort -u | head -20'
echo ""
echo "=== 3) zygote/libart icinde sessiz cikis noktalari ==="
A 'strings /apex/com.android.art/lib64/libart.so 2>/dev/null | grep -iE "bootclasspath|preload.*fail|Failed to open .*art|Unable to open" | head -10'
echo ""
echo "=== 4) framework/abc ve bootclasspath.pb ==="
A 'ls -l /system/etc/classpaths/bootclasspath.pb /system/framework/framework.abc 2>&1 | head -4'
A 'strings /system/etc/classpaths/bootclasspath.pb 2>/dev/null | head -8'
echo ""
echo "=== 5) dalvik.vm.imagepath / boot image ayarlari ==="
A 'getprop | grep -E "dalvik.vm.image|dalvik.vm.boot|dalvik.vm.dex2oat-threads" | head -8'