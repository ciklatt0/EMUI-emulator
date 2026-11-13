#!/bin/bash
# adbd auth gereksinimi: IsAdbSecure() = ro.adb.secure (yoksa ro.secure).
# auth acilirsa adbd init'ten ANDROID_SOCKET_adbd fd'si bekliyor ve
# "Failed to get adbd socket: Operation not permitted" diye BAGLANTI
# KURULMADAN birakiyor (tcp5555=0 olcduk).
# Cozum: ro.adb.secure=0 yazip /system/build.prop'u bind-mount ile degistirmek.
set -u
D=/root/harmony-build/boot/system-disk.img
for f in /system/build.prop /system/etc/prop.default /vendor/build.prop; do
  echo "=== $f ==="
  dump.erofs --offset=1048576 --cat --path="$f" "$D" 2>/dev/null \
    | grep -E '^(ro\.secure|ro\.adb\.secure|ro\.debuggable|ro\.build\.type|ro\.product)' | head -8
  echo ""
done