#!/bin/bash
# /sys/kernel/tracing sysfs'te YOK (CONFIG_FTRACE kapali) ve
# mkdir yasak. Ama atrace IKINCI konumu da kabul ediyor:
#   /sys/kernel/debug/tracing
# debugfs mount edilebiliyor mu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) kernel yapilandirmasinda debugfs ==="
A 'zcat /proc/config.gz 2>/dev/null | grep -E "CONFIG_DEBUG_FS|CONFIG_TRACEFS_FS|CONFIG_FTRACE " || echo "(config.gz yok)"'
echo ""
echo "=== 2) debugfs mount edilebilir MI ==="
A 'mkdir -p /sys/kernel/debug 2>/dev/null; ls -d /sys/kernel/debug 2>&1
   mount -t debugfs debugfs /sys/kernel/debug 2>&1 && echo "  debugfs BAGLANDI"
   mount -t debugfs debugfs /tmp 2>&1 && echo "  (gecici olarak /tmp ye baglandi)"'
echo ""
echo "=== 3) debugfs uzerinden tracing dizini ==="
A 'mount | grep -c debugfs
   ls /sys/kernel/debug/ 2>/dev/null | head -10
   echo "--- tracing var mi:"; ls -d /sys/kernel/debug/tracing 2>&1'
echo ""
echo "=== 4) /tmp uzerine baglandiysa orada gorunuyor mu ==="
A 'ls /tmp/ 2>/dev/null | head -15'