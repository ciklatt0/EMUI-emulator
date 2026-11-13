#!/bin/bash
# MASTER rc = /system/etc/init/hw/init.rc (ustteki yorum bunu soyluyor).
# Bizim onceki grep'imiz yalnizca /system/etc/init/*.rc (top-level)
# bakmisti; hw/ alt dizinini GORMEMIŞTI.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) hw/ dizini ==="
A 'ls /system/etc/init/hw/ | head -20'
echo ""
echo "=== 2) MASTER hw/init.rc -- zygote import satirlari ==="
A 'grep -n "import" /system/etc/init/hw/init.rc 2>&1 | head -30'
echo ""
echo "=== 3) hw/init.rc'nin zygote ile ilgili satirlari ==="
A 'grep -n -i "zygote" /system/etc/init/hw/init.rc 2>&1 | head -15'
echo ""
echo "=== 4) tum hw/*.rc icinde 'import' ==="
A 'grep -rn "import" /system/etc/init/hw/*.rc 2>&1 | head -20'