#!/bin/bash
# HIPOTEZ: linker config BOLUMUNU ikilinin YOLUNE gore secer.
#   /system/bin/...  -> [system]
#   /apex/<ad>/...   -> [<ad>]
#   /vendor/bin/...  -> [vendor]
# Ama /system aslinda /r/system'e symlink ve KERNEL LOGUNDA
# gorulen yol "/r/system/bin/init". Bu [system] ile eslesmezse
# hicbir arama yolu olmayan default bolume duser -> libc.so not found.
#
# AYIRT EDICI DENEY: ayni ikiliyi iki yoldan calistir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /system yolu (symlink uzerinden) ==="
A '/system/bin/getprop ro.product.model 2>&1 | head -2'
echo ""
echo "=== 2) /r/system yolu (gercek yol) ==="
A '/r/system/bin/getprop ro.product.model 2>&1 | head -2'
echo ""
echo "=== 3) /system/bin/ueventd ve /r/system/bin/ueventd ==="
A '/system/bin/getprop init.svc.ueventd 2>&1'
A 'ls -l /r/system/bin/getprop /system/bin/getprop 2>&1'
echo ""
echo "=== 4) readlink: /system gercekten /r/system mi ==="
A 'ls -ld /system; readlink /system'
echo ""
echo "=== 5) vendor alt baglami hangi yolla baslatiyor (init logu) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -a "subcontext\|CANNOT LINK EXECUTABLE" "$F" | tail -4 | sed 's/\[[^]]*\] //' | cut -c1-150