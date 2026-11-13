#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) hw/init.rc satir 40-75 (linkerconfig blogu) ==="
A 'sed -n "40,75p" /system/etc/init/hw/init.rc'
echo ""
echo "=== 2) /linkerconfig mount durumu ==="
A 'mount | grep linkerconfig'
echo ""
echo "=== 3) init bu blogu calistirdi mi (linkerconfig servisi) ==="
A 'getprop init.svc.linkerconfig; getprop init.svc.ueventd'