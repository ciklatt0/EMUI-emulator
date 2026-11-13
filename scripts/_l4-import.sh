#!/bin/bash
# 'Failed to set property ctl.start to zygote' = init zygote
# SERVISINI TANIYAMIYOR. service zygote tanimi
# /system/etc/init/hw/init.zygote64_32.rc icinde; yani bir 'import'
# satiriyla gelmesi gerekiyor.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) init.rc'de zygote import'u var mi ==="
A 'grep -n "zygote" /system/etc/init/init.rc 2>/dev/null | head -10'
echo ""
echo "=== 2) TUM import satirlari (ilk 25) ==="
A 'grep -n "^import" /system/etc/init/init.rc 2>/dev/null | head -25'
echo ""
echo "=== 3) yorumlanmis import satirlari (# ile baslayan) ==="
A 'grep -n "^#[ ]*import" /system/etc/init/init.rc 2>/dev/null | head -12'
echo ""
echo "=== 4) hw/ dizini overlay'de var mi ==="
A 'ls /system/etc/init/hw/ 2>&1 | head -8; echo "---"; ls /system/etc/init/hw/init.zygote*.rc 2>&1'
echo ""
echo "=== 5) tombstone (cozulen surec) ==="
A 'ls -t /data/tombstones/ 2>/dev/null | head -3'
A 'logcat -d 2>/dev/null | grep -iE "tombstoned|Fatal signal|crash_dump" | tail -6'