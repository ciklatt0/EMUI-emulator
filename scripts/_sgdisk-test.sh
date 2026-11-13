#!/bin/bash
# data bolumunun neden olusmadigini sgdisk'in kendi hata ciktisiyla gosterir.
set -u
SECTORS=$((18255104))
D=/tmp/t.img
rm -f "$D"
truncate -s $((SECTORS * 512)) "$D"
sgdisk --clear "$D"
echo "--- 1. bolumu (kontrol) ---"
sgdisk --new=1:2048:2097151 --change-name=1:x "$D" 2>&1 | tail -2
echo "--- 29. bolumu (data) ---"
sgdisk --new=29:16123904:18221055 --change-name=29:data "$D" 2>&1 | tail -5
echo "cikis=$?"
echo "--- tablo ---"
sgdisk -p "$D" 2>&1 | tail -6