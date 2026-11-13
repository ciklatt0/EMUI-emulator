#!/bin/bash
# 'Failed to set property ctl.start to zygote' = init zygote
# servisini TANIYAMIYOR. /system/etc/init/init.rc YOK. Gercek rc
# agaci nerede ve init ne mount etti?
HERE="$(cd "$(cd "$(dirname "$0")" && pwd)" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /system/etc/init icerigi ==="
A 'ls /system/etc/init/ 2>&1 | head -20'
echo ""
echo "=== 2) tum mount'lar (/system ile ilgili) ==="
A 'cat /proc/mounts 2>/dev/null | grep -E "/system|/r/|rc" | head -25'
echo ""
echo "=== 3) tum init.rc dosyalari (find) ==="
A 'ls /init*.rc /bb/*.rc 2>/dev/null; echo "---"; ls -la / 2>&1 | head -25'
echo ""
echo "=== 4) /r nesi (tombstone'da /r/system/bin/vold) ==="
A 'ls /r 2>&1 | head; echo "---"; ls /r/etc/init 2>&1 | head -10'