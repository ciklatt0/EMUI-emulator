#!/bin/bash
# Ilk dosya (update_full_base.zip) Android tarzi OTA paketi gibi
# gorunuyor (UPDATE.APP, update-binary, CERT.RSA). Surumu ve
# cihazini okuyalim. AYRICA: NOH-AN00 icin NEXT paketi var mi?
# Tum Downloads'ta NOH/ALN/PLA/SGT adlarini ara.
set -u
cd "$(dirname "$0")/../Downloads" || exit 1

echo "=== ilk paketin surumu ==="
for f in OTA_update.tag UPT_VER.tag SOFTWARE_VER.mbn VERSION.mbn full_mainpkg.tag packageinfo.mbn; do
  out=$(unzip -p "update_full_base.zip" "$f" 2>/dev/null | tr -c '[:print:]\n' '.' | head -c 250)
  [ -n "$out" ] && echo "  [$f] $out"
done
echo ""
echo "--- board_list / BOARDID_LIST ---"
unzip -p "update_full_base.zip" "BOARDID_LIST.mbn" 2>/dev/null | tr -c '[:print:]\n' '.' | head -c 400
echo ""
echo ""
echo "=== Downloads'ta NOH / ALN / PLA / SGT adli dosyalar ==="
ls -la --time-style=long-iso 2>/dev/null | grep -iE 'noh|aln|pla|sgt|next|5\.0|6\.0' | head -20
echo ""
echo "=== Downloads tam liste (firmware olabilecekler) ==="
ls -la --time-style=long-iso 2>/dev/null | awk '$5 > 500000000 {printf "%12s  %s %s  %s\n", $5, $6, $7, $8}' | head -25