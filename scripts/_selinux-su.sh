#!/bin/bash
# --root_seclabel=u:r:su:s0 -> adbd bu alana setcon() dener.
# 'su' alani politika dosyasinda YOKSA setcon basarisiz olur ve
# adbd ANINDA olur -- svc=restarting'in en guclu adayi.
set -u
D=/root/harmony-build/boot/system-disk.img
SOFF=1048576

echo "=== SELinux politika dosyalari ==="
dump.erofs --offset=$SOFF --ls --path=/system/etc/selinux "$D" 2>/dev/null | head -20
echo ""
echo "=== type tanimlari: su / adbd / shell ==="
for p in /system/etc/selinux/plat_sepolicy.cil /system/etc/selinux/vendor_sepolicy.cil; do
  echo "--- $p ---"
  dump.erofs --offset=$SOFF --cat --path="$p" "$D" 2>/dev/null \
    | grep -oE 'type [a-z_]+' | sort -u | grep -xE 'type su|type adbd|type shell|type init' \
    || echo "  (bulunamadi / erisilemedi)"
done