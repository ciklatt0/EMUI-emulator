#!/system/bin/sh
echo "=== libicu aramasi ==="
find /apex /system /vendor -name "libicu*" 2>/dev/null
echo "=== libicu tam yol ara ==="
find / -name "libicu*" 2>/dev/null | head -20
echo "=== APEX listesi ==="
ls /apex/ 2>/dev/null
