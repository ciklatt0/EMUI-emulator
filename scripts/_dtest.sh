#!/bin/bash
# /data konukta TMPFS. /init'in ext4 mount denemesi sonucu
# seri logda gorunmuyor. Dogrudan canli deneyelim:
# vda29 gercekten ext4 mi, mount edilebiliyor mu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /devblk altinda bolumler ==="
A 'ls /devblk/ 2>&1 | tr "\n" " " | cut -c1-300'
echo ""
echo "=== 2) vda29 superblock imzasi (ext4 magic 0xEF53 @ 0x438) ==="
A 'D=/devblk/vda29
   [ -b "$D" ] && echo "  $D blok cihaz VAR" || echo "  $D YOK"
   /bb/dd if=$D bs=1 skip=1080 count=2 2>/dev/null | /bb/od -An -tx1'
echo ""
echo "=== 3) ext4 olarak mount DENE (bos /mnt/test) ==="
A 'mkdir -p /mnt/dtest 2>/dev/null
   mount -t ext4 -o rw /devblk/vda29 /mnt/dtest 2>&1 && echo "  EXT4 MOUNT BASARILI" && ls /mnt/dtest | head -8
   mount | grep dtest'
echo ""
echo "=== 4) farkli bolumlar: 28, 29, 30 ==="
A 'for n in 28 29 30; do
   D=/devblk/vda$n
   if [ -b "$D" ]; then
     SB=$(/bb/dd if=$D bs=1 skip=1080 count=2 2>/dev/null | /bb/od -An -tx1 | tr -d " \n")
     case "$SB" in
       ef53) echo "  vda$n: ext4 imzasi VAR" ;;
       *)    echo "  vda$n: baska dosya sistemi (imza=$SB)" ;;
     esac
   else echo "  vda$n: yok"; fi
 done'
echo ""
echo "=== 5) /data su an ne ==="
A 'mount | grep " /data "
   echo "--- vold durumu:"; getprop init.svc.vold'