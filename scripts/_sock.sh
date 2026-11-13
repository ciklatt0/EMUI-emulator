#!/bin/bash
# libandroid_runtime.so icinde:
#   /dev/socket/arkinit
#   /dev/socket/arkinit_usap_pool
#   Failed to dlopen libandroid.so!
#   ark.log.level / ark.use.jit
# Yani Huawei runtime'i arkinit SOCKET'ine bagliyor.
# Socket yoksa runtime kurulumu yarida kalir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /dev/socket icinde ne var ==="
A 'ls -la /dev/socket/ 2>&1 | head -15'
echo ""
echo "=== 2) logdr / adbd / logd socketleri ==="
A 'for s in logdr logd adbd arkinit arkinit_usap_pool rild; do
   [ -e /dev/socket/$s ] && echo "  VAR  $s" || echo "  YOK  $s"
 done'
echo ""
echo "=== 3) logcat'te 'arkinit' socket hatalari ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "arkinit|socket|logdr|logd" | grep -viE "init.svc|avc:|s_servicemanager" | tail -10; echo "(bos ise sessiz)"'
echo ""
echo "=== 4) libandroid_runtime.so: logdr + dlopen libandroid ==="
A 'strings /system/lib64/libandroid_runtime.so 2>/dev/null | grep -E "^/dev/socket|^/system/lib64/libandroid.so|libandroid.so" | head -10'
echo ""
echo "=== 5) /system/lib64/libandroid.so var MI (Failed to dlopen libandroid.so!) ==="
A 'ls -l /system/lib64/libandroid.so 2>&1; find /apex -name libandroid.so 2>/dev/null | head -3'