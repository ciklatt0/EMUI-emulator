#!/bin/bash
# vendor/etc/init icindeki rc dosyalarini listeler.
D=/root/harmony-build/boot/system-disk.img
OFF=$((11806720 * 512))
dump.erofs --offset=$OFF --ls --nid=774912 "$D" 2>/dev/null > /tmp/vendor-etc.txt
echo "--- /vendor/etc ---"
head -25 /tmp/vendor-etc.txt
echo "--- /vendor/etc/init ---"
N=$(awk '$3=="init"{print $1; exit}' /tmp/vendor-etc.txt)
echo "init nid: $N"
dump.erofs --offset=$OFF --ls --nid="$N" "$D" 2>/dev/null | grep -E "graphics|composer" | head -10