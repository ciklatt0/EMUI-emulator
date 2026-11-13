#!/bin/bash
# app_process64 /data/dalvik-cache/arm64 OLUSTURUP chmod/chown
# ediyor. Basarisiz olursa hata basar ve (AOSP'da) cikar.
# zygote servisi "stdio_to_kmsg" kullandigi icin bu hatalar
# SERI LOGDA gorunur.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) SERI LOG: dalvik-cache / cache dir hatalari ==="
grep -aE "dalvik-cache|dalvik cache|cache dir|Error constructing|ANDROID_DATA|abilist" "$F" | tail -15 | sed 's/\[[^]]*\] //' | cut -c1-160
echo "  (bos ise bu hatlar hic basilmamis)"
echo ""
echo "=== 2) /data/dalvik-cache diskte var MI ==="
A 'ls -ld /data /data/dalvik-cache 2>&1
   echo "--- /data icindekiler (ilk 20):"
   ls /data/ 2>/dev/null | head -20'
echo ""
echo "=== 3) ro.product.cpu.abilist64 (app_process bunu okuyor) ==="
A 'getprop ro.product.cpu.abilist64; getprop ro.product.cpu.abilist; getprop ro.product.cpu.abilist32'
echo ""
echo "=== 4) /data yazilabilir MI (cache olusturma sarti) ==="
A 'mount | grep " /data "
   touch /data/.yazma_testi 2>&1 && echo "  /data YAZILABILIR" && rm -f /data/.yazma_testi
   mkdir -p /data/dalvik-cache/arm64 2>&1 && echo "  mkdir /data/dalvik-cache/arm64 BASARILI" && ls -ld /data/dalvik-cache /data/dalvik-cache/arm64'