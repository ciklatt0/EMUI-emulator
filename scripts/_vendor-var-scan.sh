#!/bin/bash
# Vendor rc dosyalarindaki ${...} DEGISKEN genislemesi kullanimini tarar.
# DIKKAT: init, "import" satirindaki degiskeni cozemediginde dosyayi
# bulamaz ve ALT BAGLAMI OTURTUR (Subcontext exited with status 1).
# Yalnizca 'import' icindekiler öldürücü; service argümanlarındakiler
# sadece calisma aninda hataya yol acar.
set -u
D=/tmp/vendor-rc
echo "=== 'import' satirinda degisken ==="
grep -rn 'import' "$D" 2>/dev/null | grep '\$' | sed "s#$D/##"
echo ""
echo "=== toplam degisken kullanimi (dosya:adet) ==="
grep -rc '\$' "$D" 2>/dev/null | sort -t: -k2 -rn | head -10
echo ""
echo "=== hangi ozellikler genisletiliyor (benzersiz) ==="
grep -rho '\${[A-Za-z0-9_.]*}' "$D" 2>/dev/null | sort | uniq -c | sort -rn | head -25