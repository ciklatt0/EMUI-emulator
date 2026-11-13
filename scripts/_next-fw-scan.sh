#!/bin/bash
# HANGI NEXT FIRMWARE DOSYALARI VAR? Sadece listeleme, hicbir seye
# dokunma. Once buyuk dosyalari (super.img, *.img, *.zip) ara.
set -u
echo "=== Buyuk imaj dosyalari (>= 500 MB) ==="
find . /root/harmony-build /mnt/d 2>/dev/null \
     \( -iname '*.img' -o -iname '*.zip' -o -iname '*.tar*' -o -iname '*.7z' -o -iname '*.xz' \) \
     -size +500M -printf '%10s  %p\n' 2>/dev/null | sort -rn | head -30
echo ""
echo "=== 'next' / 'harmonyos' / '5.0' / '6.0' adli diziz ve dosyalar ==="
find . /root/harmony-build 2>/dev/null -maxdepth 4 \
     \( -iname '*next*' -o -iname '*harmony*' -o -iname '*hos*' \) \
     -printf '%y %10s  %p\n' 2>/dev/null | head -30