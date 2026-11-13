#!/bin/bash
set -u
R=/root/harmony-build/initramfs-boot
echo "--- /bb/nb/nb/null var mi (cift sed) ---"
grep -rn 'nb/nb/null' "$R" 2>/dev/null | head -3
echo "(bos ise temiz)"
echo ""
echo "--- /init ilk 25 satir ---"
sed -n '1,25p' "$R/init"
echo ""
echo "--- /init icindeki bb/nb blogu ---"
grep -n -B2 -A6 'bb/nb' "$R/init" | head -30
echo ""
echo "--- /data blogu ---"
grep -n -B2 -A6 'vda29\|vda27' "$R/init" | head -20
echo ""
echo "--- bash -n kontrolu ---"
bash -n "$R/init" && echo "  [ok] sozdizimi"