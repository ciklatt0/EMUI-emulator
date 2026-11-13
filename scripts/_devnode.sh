#!/bin/bash
# /init'in /data mount'u iki asama:
#   satir 3144:  /devblk/vda29 (ext4) dener
#   satir 3277:  mountpoint yoksa tmpfs baglar
# AMA /devblk/vda29 dugumu satir 214'te bb/mountapex ICINDE
# olusturuluyor -- yani 3144'ten SONRA. O an /devblk/vda29
# yok, -b testi basarisiz, ext4 atlanir ve tmpfs baglanir.
# Dogrulama: /dev/vda29 ve /devblk/vda29 var mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /dev/vda29 ve /devblk/vda29 ==="
A 'ls -l /dev/vda29 /devblk/vda29 2>&1
   echo "--- -b testi:"
   [ -b /dev/vda29 ] && echo "  /dev/vda29  BLOK CIHAZ" || echo "  /dev/vda29  blok degil"
   [ -b /devblk/vda29 ] && echo "  /devblk/vda29 BLOK CIHAZ" || echo "  /devblk/vda29 blok degil"'
echo ""
echo "=== 2) /dev/vda29 uzerinden ext4 mount DENEME ==="
A 'mkdir -p /mnt/d2 2>/dev/null
   mount -t ext4 -o rw /dev/vda29 /mnt/d2 2>&1 && echo "  /dev/vda29 ile EXT4 MOUNT BASARILI" && ls /mnt/d2 | head -8
   umount /mnt/d2 2>/dev/null'
echo ""
echo "=== 3) vda29 bos mu dolu mu (boyut) ==="
A '/bb/dd if=/devblk/vda29 bs=4096 count=2 2>/dev/null | /bb/od -An -tx1 | head -2
   echo "--- superblock magic (458-459):"
   /bb/dd if=/devblk/vda29 bs=1 skip=1082 count=2 2>/dev/null | /bb/od -An -tx1'