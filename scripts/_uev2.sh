#!/bin/bash
# /dev/socket/ueventd YOK ama init.svc.ueventd=running.
# vold dizelerinde "Unable to bind uevent socket" var.
# AOSP'de ueventd'nin kontrol soketi /dev/socket/ueventd'dir ve
# init servis taniminda "socket ueventd seqpacket" ile verilir.
# rclog bunu yorumladi mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) ueventd servis taniminin TAMAMI (yamalanmis) ==="
A 'for f in /system/etc/init/hw/init.rc /system/etc/init/ueventd.rc /init.environ.rc; do
   [ -f "$f" ] || continue
   awk "/^service ueventd/,/^}/" "$f" 2>/dev/null | sed "s|^|  [\$f] |" | head -14
 done'
echo ""
echo "=== 2) socket satiri var MI (her yerde) ==="
A 'grep -rn "socket ueventd\|ueventd seqpacket\|seqpacket" /system/etc/init/ /init.environ.rc 2>/dev/null | head -6
   echo "  (bos ise socket tanimi hic yok)"'
echo ""
echo "=== 3) STOK halinde var miydi? (yamalanmamis kaynak) ==="
A 'grep -rn "ueventd" /system/etc/init/hw/init.rc 2>/dev/null | head -6 | cut -c1-100'
echo ""
echo "=== 4) ueventd calisiyor mu, ne yapiyor ==="
A 'P=$(getprop init.svc_debug_pid.ueventd); echo "  pid=$P"
   [ -n "$P" ] && [ -d /proc/$P ] && { echo "  exe=$(readlink /proc/$P/exe)"; echo "  env:"; tr "\0" "\n" < /proc/$P/environ 2>/dev/null | grep -E "UEVENTD|socket" | head -4; }'
echo ""
echo "=== 5) vold logu: hangi asamada dustu ==="
A 'logcat -d -b all 2>/dev/null | grep -i "vold" | grep -v "avc:" | tail -8'