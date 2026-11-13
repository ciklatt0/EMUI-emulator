#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /dev/socket/ueventd var MI (hedef) ==="
A 'ls -l /dev/socket/ueventd 2>&1 | head -1
   echo "  --- /dev/socket tam liste:"
   ls /dev/socket/ 2>/dev/null | tr "\n" " "'
echo ""
echo "=== 2) vold hangi yollari ariyor (strings) ==="
A 'strings /system/bin/vold 2>/dev/null | grep -E "^/dev/|ueventd|socket" | head -12'
echo ""
echo "=== 3) ASHMEM: kernelde derlenebilir MI (kaynak agacinda) ==="
bash -c 'ls /root/harmony-build/linux-6.6/drivers/staging/android/ 2>/dev/null | head -5
grep -n "^config ASHMEM" -A 5 /root/harmony-build/linux-6.6/drivers/staging/android/Kconfig 2>/dev/null | head -8
echo "--- mevcut .config:"
grep -E "^(# )?CONFIG_ASHMEM" /root/harmony-build/linux-6.6/.config 2>/dev/null || echo "  ASHMEM sembolu .configda HIC YOK"'
echo ""
echo "=== 4) ashmem'i kullananlar (vendor HAL) ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "ashmem" | grep -v "avc:" | tail -4
   echo "--- hangi surec:"
   logcat -d -b all 2>/dev/null | grep -i "Unable to open ashmem" | tail -2'