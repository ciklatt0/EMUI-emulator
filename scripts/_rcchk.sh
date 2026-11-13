#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) firmware rc ağacında servicemanager ==="
A 'grep -rn "service servicemanager\|service hwservicemanager" /system/etc/init/ 2>/dev/null | head -4'
echo ""
echo "=== 2) OVERLAY (baglanan) rc'de var mi ==="
A 'ls -l /overlay-rc/system/etc/init/hw/init.rc 2>&1 | head -2'
A 'grep -rn "service servicemanager" /overlay-rc/ 2>/dev/null | head -3'
echo ""
echo "=== 3) master rc'deki import satirlari ==="
A 'grep -n "^import\|^# RCYAMALAMA.*import" /system/etc/init/hw/init.rc | head -12'
echo ""
echo "=== 4) init.svc.* toplam sayisi ==="
A 'getprop | grep -c "\[init.svc"'
echo ""
echo "=== 5) zygote tanimli mi (kontrol: ayni yoldan geliyor) ==="
A 'getprop init.svc.zygote'