#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) kok dizinde /init.*.rc ==="
A 'ls /init*.rc 2>&1'
echo ""
echo "=== 2) /vendor/etc/init/hw/init.*.rc ==="
A 'ls /vendor/etc/init/hw/init.*.rc 2>&1 | head -6'
echo ""
echo "=== 3) ro.hardware ne ==="
A 'getprop ro.hardware; getprop androidboot.hardware'
echo ""
echo "=== 4) ozel rc dosyalarinin icerigi (varsa) ==="
A 'head -12 /vendor/etc/init/hw/init.qemu.rc 2>&1'
echo ""
echo "=== 5) kaç servis tanimli (stok) vs yuklu ==="
A 'grep -rhc "^service" /system/etc/init/*.rc 2>/dev/null | /bb/awk "{s+=\$1} END{print \"stok ustservis: \"s+0}"'
A 'getprop | grep -c "\[init.svc"'