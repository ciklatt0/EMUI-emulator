#!/bin/bash
# Gercek firmware rc dosyalari UZERINDE rcpatch awk'sini dogrudan
# calistirir (QEMU'suz, 1 saniye).
#
# DIKKAT: 93-test-rcpatch.sh yalnizca 4 dosya kullanir ve bunlar
# super-out/parts'teki ESKI imajlardan gelir. Bu betik /tmp/vendor-rc
# altindaki 102 GERCEK vendor rc dosyasini tarar; ozellikle
# connectivity import satiri icin.
set -u
BOOT="$(dirname "$0")/81-boot-zygote.sh"
A0=$(grep -n 'awk -v OVL=' "$BOOT" | head -1 | cut -d: -f1)
A1=$(grep -n 'rclog\.stats' "$BOOT" | head -1 | cut -d: -f1)
sed -n "$((A0 + 1)),$((A1 - 1))p" "$BOOT" \
  | sed "1s/^ *'//" | sed '$s/'"'"' .*$//' > /tmp/rcpatch.awk

D=/tmp/vendor-rc
if [ ! -d "$D" ]; then
  echo "once _vendor-rc-scan.sh calistir"
  exit 1
fi
OVL=/tmp/rcverify-out
SRC=/tmp/vendor-rc
rm -rf "$OVL"; mkdir -p "$OVL"

awk -v OVL="$OVL" -v SRC="$SRC" -f /tmp/rcpatch.awk $D/*.rc > /tmp/rcverify.stats 2>/dev/null
echo "awk istatistik: $(cat /tmp/rcverify.stats)"
echo "  (alanlar: NR wait modem crit krit reboot shutdown apexdstat writepid filefd import)"
echo ""
echo "=== connectivity rc sonucu (ilk 6 satir) ==="
sed -n '1,6p' "$OVL/$(ls "$OVL" | grep connectivity | head -1)"
echo ""
echo "=== kalan degiskenli import (0 olmali) ==="
grep -rn 'import.*\${' "$OVL" 2>/dev/null | grep -v 'RCYAMALAMA' | head
echo "(bos ise temiz)"
echo ""
echo "=== writepid / file kalan aktif satirlar (0 olmali) ==="
grep -rhcE '^[[:space:]]*(writepid|file)[[:space:]]' "$OVL"/*.rc 2>/dev/null | grep -v '^0$' | head
echo "(bos ise temiz)"