#!/bin/bash
# vold'un BlkidContext yapicisi SocketListener ile /dev/socket/ueventd
# acar. Android 12'de bu android_get_control_socket("ueventd") ile
# olur; bu da ANDROID_SOCKET_ueventd ORTAM DEGISKENINI okur.
# O degiskeni init, servis tanimindaki "socket ueventd ..." satiri
# ile verir. vold'un taniminda o satiri var mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) vold servis taniminin TAMAMI ==="
A 'for f in /system/etc/init/*.rc /system/etc/init/hw/*.rc /init.environ.rc; do
   [ -f "$f" ] || continue
   awk "/^service vold/,/^}/" "$f" 2>/dev/null | head -14 | sed "s|^|  [${f##*/}] |"
 done'
echo ""
echo "=== 2) vold'un ORTAMI (canli yakalama) ==="
A 'logcat -b all -c 2>/dev/null
   setprop ctl.stop vold 2>/dev/null; /bb/sleep 1
   setprop ctl.start vold
   i=0
   while [ $i -lt 40 ]; do
     P=$(getprop init.svc_debug_pid.vold 2>/dev/null)
     if [ -n "$P" ] && [ -d /proc/$P ] && [ -n "$(readlink /proc/$P/exe 2>/dev/null)" ]; then
       echo "  vold pid=$P yakalandi"
       tr "\0" "\n" < /proc/$P/environ 2>/dev/null | grep -E "ANDROID_SOCKET|SOCKET" | sed "s/^/    /"
       echo "    --- exe=$(readlink /proc/$P/exe)"
       break
     fi
     i=$((i+1)); /bb/sleep 0.05
   done
   [ $i -ge 40 ] && echo "  vold 2 sn icinde yakalanamadi (cok hizli oluyor)"'
echo ""
echo "=== 3) tum servislerde socket ueventd tanimi var MI ==="
A 'grep -rn "socket ueventd\|ueventd seqpacket\|ueventd stream" /system/etc/init/ /vendor/etc/init/ /init.environ.rc 2>/dev/null | head -4
   echo "  (bos = HICBIR yerde ueventd soketi tanimli degil)"'