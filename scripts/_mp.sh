#!/bin/bash
# ensure_data_dirs korumasi "mountpoint -q /data" UZERINE kurulu.
# /data tmpfs ama koruma "zaten mountlu" deyip gecmis olmali.
# mountpoint bu ortamda guvenilir mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) mountpoint -q /data gercekten ne donuyor ==="
A 'mountpoint -q /data; echo "  mountpoint -q /data  -> RC=$?  (0=mount noktasi)"
   mountpoint -q /system; echo "  mountpoint -q /system -> RC=$?"
   mountpoint -q /apex;    echo "  mountpoint -q /apex    -> RC=$?"
   mountpoint -q /tmp;     echo "  mountpoint -q /tmp     -> RC=$?"
   mountpoint -q /mnt/dtest; echo "  mountpoint -q /mnt/dtest -> RC=$? (bilerek mountlu)"'
echo ""
echo "=== 2) /proc/mounts icinde /data ==="
A 'grep " /data " /proc/mounts'
echo ""
echo "=== 3) /data icerigi (tmpfs ise bostur) ==="
A 'ls /data/ 2>&1 | tr "\n" " " | cut -c1-200'
echo ""
echo "=== 4) SONUC: mountpoint calisiyorsa ext4 mount neden basarisiz? ==="
echo "  -> /init'te ext4 mount bir kez deneniyor. Basarisizsa"
echo "     /data DIZIN olarak kalir ve ensure_data_dirs tmpfs baglar."
echo "  -> simdi ayni mountu elle tekrarlayalim:"
A 'umount /data 2>/dev/null; mount -t ext4 -o rw /devblk/vda29 /data 2>&1; echo "  RC=$?"; mount | grep " /data "'