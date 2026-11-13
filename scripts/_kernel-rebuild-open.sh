#!/bin/bash
# Kernel yeniden derlemesi icin guard'i acmak.
# Betik, 'phase1/kernel/Image' dosyasi .config'den yeniyse derlemeyi
# ATLAR. IPv6 config'ini degistirebilmek icin Image'i yedekleyip
# silmeliyiz.
set -u
K="$(dirname "$0")/../phase1/kernel"
IMG="$K/Image"
echo "=== mevcut durum ==="
ls -l --time-style=long-iso "$IMG" 2>/dev/null
ls -l --time-style=long-iso /root/harmony-build/linux-6.6/.config 2>/dev/null
echo ""
if [ ! -f "$K/Image.bak-ipv6" ]; then
  cp -p "$IMG" "$K/Image.bak-ipv6" && echo "yedek alindi: Image.bak-ipv6"
else
  echo "yedek zaten var"
fi
rm -f "$IMG" && echo "Image silindi (derleme yeniden baslayacak)"
echo ""
echo "=== yedek ==="
ls -l --time-style=long-iso "$K/Image.bak-ipv6"