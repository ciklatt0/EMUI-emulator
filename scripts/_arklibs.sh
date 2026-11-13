#!/bin/bash
# KIRMA NOKTASI:
#   ark dlopen("libartbased.so") -> BASARISIZ
#   ark dlopen("libartbase.so")  -> TAMAM
#   ark dizeleri: libarkruntime.so, start-as-zygote,
#                 java.force-zygote-fork-loop
#
# YANLIS DENEYIMIZ: ro.ark.enable=0 yaptik ve VM hic olusmadi.
# Geri almamiz gerekiyor (build.prop yamasini kaldirmak).
# Ama once bu iki kutuphanenin diskte olup olmadigini olcelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libartbased.so ve libarkruntime.so diskte MI ==="
A 'for f in libartbased.so libartbase.so libarkruntime.so; do
   echo "  --- $f"
   find /system /apex /vendor -maxdepth 4 -name "$f" 2>/dev/null | head -3 | sed "s/^/      /"
   [ -z "$(find /system /apex /vendor -maxdepth 4 -name "$f" 2>/dev/null | head -1)" ] && echo "      YOK"
 done'
echo ""
echo "=== 2) ark hangi pandastdlib/abc dosyalarini bekliyor ==="
A 'ls -l /system/pandastdlib/ 2>&1 | head -8
   echo "  --- arkstdlib.abc:"
   ls -l /system/pandastdlib/arkstdlib.abc 2>&1 | head -1
   echo "  --- abc dosyalari (ilk 8):"
   find /system -name "*.abc" 2>/dev/null | head -8'
echo ""
echo "=== 3) ark ZYGOTE modunu deneyelim ==="
A 'cd /; timeout 15 /system/bin/ark --start-as-zygote 2>&1 | head -12; echo "RC=$?"'
echo ""
echo "=== 4) ark dltrace ile zygote modu ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   LD_PRELOAD=/data/dltrace.so timeout 18 /system/bin/ark --start-as-zygote >/dev/null 2>/tmp/az.err
   echo "  RC=$?"
   /bb/head -20 /tmp/az.err'
echo ""
echo "=== 5) framework.abc (ark surumu) var MI ==="
A 'find /system -maxdepth 3 -name "framework*.abc" -o -maxdepth 3 -name "*.abc" 2>/dev/null | head -5
   echo "  --- /system/framework icerigi:"
   ls /system/framework/ 2>/dev/null | head -8'