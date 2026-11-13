#!/bin/bash
# adbd'nin NEEDED sirasi: libadbd_fs, liblog, libselinux, libbase,
# libadb_protos, libadbd_auth, libcrypto, libc++, libc, libm, libdl
# Linker libadbd_protos'i ANLAMLI... sira bozuk olabilir.
# Soru: /system/lib64 icinde libbase.so, libcutils.so, libc++.so var mi?
# Varsa "ilk bulunamayan = libadb_protos" bulgusu, arama yolunun
# /system/lib64 + bonic'den ibaret oldugunu (APEX lib64 HARIC) gosterir.
set -u
D=/root/harmony-build/boot/system-disk.img
echo "--- /system/lib64: adbd'nin ihtiyac duydugu butun kutuphaneler ---"
for l in libadbd_fs libadbd_auth liblog libselinux libbase libadb_protos libadbd_auth libcutils libc++ libcrypto; do
  if dump.erofs --offset=1048576 --ls --path=/system/lib64 "$D" 2>/dev/null | grep -q " $l\.so"; then
    echo "  VAR   /system/lib64/$l.so"
  else
    echo "  YOK   /system/lib64/$l.so"
  fi
done