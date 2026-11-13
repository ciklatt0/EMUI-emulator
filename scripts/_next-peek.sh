#!/bin/bash
# NEXT paketinin icinde ne var? update.bin'in yapisi.
# SALT OKUNUR: sadece okur, hicbir yere yazmaz.
set -u
cd "$(dirname "$0")/../Downloads" || exit 1

echo "=== Disk bos alani ==="
df -h /root/harmony-build /tmp /mnt/c 2>/dev/null | grep -v tmpfs

echo ""
echo "=== update.bin header (ilk 256 bayt) ==="
# Paket (3) en yenisi (2026-03-24, HarmonyOS 6.0, SGT-AL10)
unzip -p "update_full_base (3).zip" update.bin 2>/dev/null | head -c 256 | xxd | head -16

echo ""
echo "=== update.bin icinde 'super' / 'system' imzasi araniyor ==="
# Buyuk dosyayi stream edip aramak yerine: ilk 8 MB'da sihirli
# baytlar/imzalar ara. super.img genelde 'gzip' (1f 8b) veya
# erofs (e0 f5 e1 e2) ile baslar.
unzip -p "update_full_base (3).zip" update.bin 2>/dev/null | head -c 8388608 > /tmp/_uh.bin
echo "  ilk 8 MB'de:"
for m in "1f8b:gzip" "e2e1f5e0:erofs" "425a6839:zstd" "fd377a58:xz" "fd314152:lzma"; do
  sig=${m%%:*}; name=${m##*:}
  if grep -qaob "$(printf '\x'"${sig:0:2}"'\x'"${sig:2:2}"'\x'"${sig:4:2}"'\x'"${sig:6:2}"')" /tmp/_uh.bin 2>/dev/null | head -1 | grep -q .; then
    off=$(grep -qaob -m1 "$(printf '\x'"${sig:0:2}"'\x'"${sig:2:2}"'\x'"${sig:4:2}"'\x'"${sig:6:2}"')" /tmp/_uh.bin 2>/dev/null | head -1 | cut -d: -f1)
    echo "    $name  ofset=$off"
  fi
done
echo "  (bitti)"
rm -f /tmp/_uh.bin