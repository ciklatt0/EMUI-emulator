#!/bin/bash
# 1) Tombstone'i oku -> COKEN SUREC kim?
# 2) init.rc gercekten import satiri iceriyor mu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) TOMBSTONE_08 (cozulen surecin kimligi) ==="
A 'cat /data/tombstones/tombstone_08 2>/dev/null | head -40'
echo ""
echo "=== 2) tombstone_07 ==="
A 'cat /data/tombstones/tombstone_07 2>/dev/null | head -25'
echo ""
echo "=== 3) /system/etc/init/init.rc gercek icerigi ==="
A 'ls -l /system/etc/init/init.rc; echo "--- satir sayisi:"; wc -l /system/etc/init/init.rc'
A 'head -20 /system/etc/init/init.rc'
echo ""
echo "=== 4) init hangi rc dosyalarini parse etti (property) ==="
A 'getprop | grep -iE "init\.(svc|debug)|rc\." | head -10'