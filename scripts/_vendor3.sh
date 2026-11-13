#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) [vendor] bolumunun icerigi ==="
A "sed -n '366,385p' /linkerconfig/ld.config.txt | cut -c1-180"
echo ""
echo "=== 2) [vendor] icinde i18n ve bionic var MI ==="
A "sed -n '366,385p' /linkerconfig/ld.config.txt | grep -o 'i18n/lib64\|lib64/bionic' | sort -u"
echo ""
echo "=== 3) VENDOR ikilisi testi (gercekten baglaniyor mu) ==="
A '/vendor/bin/hw/android.hardware.bluetooth@1.1-service --help 2>&1 | head -2'
A 'ls /vendor/bin | head -3'
echo ""
echo "=== 4) hangi ikililer hâlâ duser (sinif bazinda) ==="
A '/system/bin/toybox file /system/bin/audioserver /system/bin/cameraserver /system/bin/mediaserver 2>&1 | sed "s/ELF shared object, //;s/, dynamic.*//"'
echo ""
echo "=== 5) init alt baglami ne kadar calisiyor ==="
A 'logcat -d 2>/dev/null | grep -c "Forked subcontext"'
A 'getprop init.svc.servicemanager; getprop init.svc.hwservicemanager; getprop init.svc.vndservicemanager'