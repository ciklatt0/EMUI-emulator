#!/bin/bash
# 1) libandroidicu.so diskte NEREDE? ld.config [system] yollarinda var mi?
# 2) /dev/binder neden 'context object' uretmiyor?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libandroidicu.so konumu ==="
A 'find /system /vendor /apex -name "libandroidicu*" 2>/dev/null | head -10'
echo ""
echo "=== 2) /system/lib64'de mi ==="
A 'ls /system/lib64/libandroidicu* /system/lib64/libicu* 2>&1 | head -5'
echo ""
echo "=== 3) ld.config [system] arama yollari (ilk 5) ==="
A "awk '/^\[system\]/{s=1} s && /namespace.default.search.paths/{print; exit}' /linkerconfig/ld.config.txt | tr ':' '\n' | head -8"
echo ""
echo "=== 4) arama yollarinda gercekten var mi ==="
A 'for p in /system/lib64 /apex/com.android.art/lib64 /apex/com.android.runtime/lib64; do echo "$p: $(ls $p/libandroidicu* 2>/dev/null | head -1 || echo YOK)"; done'
echo ""
echo "=== 5) /dev/binder ==="
A 'ls -l /dev/binder; cat /proc/filesystems | grep -i binder'
A 'ls /sys/kernel/debug/binder 2>&1 | head -3; getprop init.svc.hwservicemanager'