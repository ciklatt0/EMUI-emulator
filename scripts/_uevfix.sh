#!/bin/bash
# vold'un CHECK failed'i: BlkidContext yapicisi mInitialized=false
# birakamiyor. Yapici SocketListener ile /dev/socket/ueventd
# ACAR. Acilamiyorsa CHECK failed.
# Iki deney:
#  A) "Unable to bind uevent socket" mesaji logda var MI
#  B) /dev/socket'a soket YARATABILIYOR muyuz (izin/mount engeli mi)
#  C) elle /dev/socket/ueventd yaratip vold'u yeniden deneyelim
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== A) vold'un 'uevent socket' mesaji logda ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "uevent socket|bind uevent|ueventd" | grep -v "avc:" | tail -6
   echo "  (bos ise mesaj hic basilmadi)"'
echo ""
echo "=== B) /dev/socket'a soket yaratabiliyor muyuz ==="
A '/bb/ls -ld /dev/socket
   mount | grep " /dev " | head -2
   echo "  --- dene:"
   /bb/rm -f /dev/socket/testsk 2>/dev/null
   if /system/bin/toybox mkfifo /dev/socket/testsk 2>&1; then echo "  fifo OLUSTURULDU -> dizin yazilabilir"; /bb/rm -f /dev/socket/testsk; else echo "  OLUSTURULAMADI"; fi'
echo ""
echo "=== C) /dev/socket/ueventd elle yarat, vold'u yeniden dene ==="
A 'setprop ctl.stop vold 2>/dev/null; /bb/sleep 1
   logcat -b all -c 2>/dev/null
   # seqpacket destekliyor mu kontrol et
   /system/bin/toybox mkfifo /dev/socket/ueventd 2>/dev/null && echo "  fifo olusturuldu"
   ls -l /dev/socket/ueventd 2>&1 | head -1
   setprop ctl.start vold; /bb/sleep 6
   echo "  --- vold logu:"
   logcat -d -b all -v time 2>/dev/null | grep -i vold | grep -v "avc:" | head -10
   echo "  svc=[$(getprop init.svc.vold)]"'