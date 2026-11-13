#!/bin/bash
# Downloads'taki update_full_base paketleri: hangisi NEXT, hepsi sağlam mi?
# Sadece OKUNUR (listeleme). Hicbir dosyaya dokunulmaz.
set -u
cd "$(dirname "$0")/../Downloads" || exit 1

for z in update_full_base.zip "update_full_base (1).zip" "update_full_base (2).zip" "update_full_base (3).zip"; do
  [ -f "$z" ] || continue
  echo "=============================================="
  echo "DOSYA : $z"
  echo "BOYUT : $(stat -c%s "$z") bayt ($(du -h "$z" | cut -f1))"
  # zip butunlugu: son 22 baytta EOCD kaydi var mi, 0x504b0506
  tail -c 22 "$z" | xxd | tail -2
  echo "--- icindeki dosya sayisi / ilk 25 giris ---"
  timeout 120 unzip -l "$z" 2>&1 | tail -n +4 | head -25
  echo ""
done