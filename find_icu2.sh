#!/system/bin/sh
echo "=== APEX dizinleri ==="
ls /apex/ 2>/dev/null
echo ""
echo "=== libicu arama (APEX altinda) ==="
for d in /apex/*/; do
  if ls "$d"lib64/libicu* 2>/dev/null; then
    echo "BULUNDU: $d"
  fi
  if ls "$d"usr/lib64/libicu* 2>/dev/null; then
    echo "BULUNDU: $d usr"
  fi
done
echo ""
echo "=== libicu arama (system altinda) ==="
ls /system/lib64/libicu* 2>/dev/null || echo "yok"
echo ""
echo "=== libicu arama (vendor altinda) ==="
ls /vendor/lib64/libicu* 2>/dev/null || echo "yok"
