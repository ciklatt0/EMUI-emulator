#!/bin/bash
# /vendor/etc/init LISTESI 0 dosya dondu -> vendor bolumunun OFFSET'i
# yanlis. GPT'den gercek baslangic sektorunu okuyalim.
set -u
D=/root/harmony-build/boot/system-disk.img
echo "=== GPT bolum tablosu ==="
sgdisk -p "$D" 2>/dev/null
echo ""
echo "=== parca numarasi + baslangic sektoru ==="
sgdisk -i 3 "$D" 2>/dev/null | grep -i 'first sector\|partition name'
echo ""
echo "--- parca 3 (vendor) icerigi: /etc/init var mi? ---"
START=$(sgdisk -i 3 "$D" 2>/dev/null | awk -F: '/First sector/{gsub(/[^0-9]/,"",$2); print $2}')
echo "  ilk sektor: $START  -> byte ofset: $((START*512))"