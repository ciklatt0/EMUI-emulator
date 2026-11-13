#!/bin/bash
# awk programi shell in TEK tirnakli dizisi icinde; yorumdaki kesme
# isareti diziyi erken kapatir ve uretilen betik sozdizimi hatasi
# verir. Bu tuzak bu seansta 5 kez basina geldi; olcum aracini
# kurmak yerine ONCEDEN tarayalim.
set -u
F="$(dirname "$0")/81-boot-zygote.sh"

echo "=== awk blogunun sinirlari ==="
S=$(grep -n "^/bb/awk -v OVL=" "$F" | head -1 | cut -d: -f1)
E=$(awk -v s="$S" 'NR>s && /^'"'"' \$FILES >/ {print NR; exit}' "$F")
echo "awk baslangic: $S"
if [ -z "${E:-}" ]; then
  E=$(awk -v s="$S" 'NR>s && /^\x27 \$FILES >/ {print NR; exit}' "$F")
fi
echo "awk bitis    : ${E:-BULUNAMADI}"

if [ -n "${E:-}" ]; then
  echo ""
  echo "=== bu araliktaki TEK tirnaklar (0 olmali) ==="
  sed -n "${S},${E}p" "$F" | grep -n "'" | head -20
  N=$(sed -n "${S},${E}p" "$F" | grep -c "'")
  echo "toplam: $N (2 olmali)"
fi