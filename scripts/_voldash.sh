#!/bin/bash
# KALAN IKI GERCEK SORUN:
#  1) vold  Check failed: sBlkidContext != nullptr
#     AOSP'de BlkidContext yapilanda mInitialized=false kalirsa
#     oluyor. Yapici /dev/ueventd soketini ve /sys/block'a
#     ihtiyac duyar.
#  2) /dev/ashmem YOK -> audio_sa "mReadPtr is null" ile cokuyor
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) arkprobe teşhis aracini kapat ==="
A 'setprop ctl.stop arkprobe; /bb/sleep 1; echo "  arkprobe=[$(getprop init.svc.arkprobe)]"'
echo ""
echo "=== 1) VOLD: yapicinin ihtiyac duydugu yollar ==="
A 'for f in /dev/ueventd /dev/block /dev/socket/logdr /sys/block /sys/class/block; do
   printf "  %-22s %s\n" "$f" "$([ -e "$f" ] && echo VAR || echo YOK)"
 done
   echo "  --- /sys/block icerigi:"
   ls /sys/block 2>/dev/null | head -8
   echo "  --- /dev/block (apexd denemisiti):"
   ls /dev/block 2>&1 | head -5'
echo ""
echo "=== 2) VOLD tam hata baglami ==="
A 'logcat -d -b crash 2>/dev/null | grep -B 2 -A 6 "sBlkidContext" | head -18'
echo ""
echo "=== 3) ASHMEM ==="
A 'ls -l /dev/ashmem 2>&1 | head -1
   echo "--- kernel yapilandirmasinda ashmem:"
   zcat /proc/config.gz 2>/dev/null | grep -iE "ASHMEM|MEMFD" || echo "  (config.gz yok)"
   echo "--- /proc/misc:"
   cat /proc/misc 2>/dev/null | head -10'
echo ""
echo "=== 4) ASHMEM yerine memfd kullanilabiliyor MU ==="
A 'strings /system/lib64/libc.so 2>/dev/null | grep -E "memfd_create|ashmem" | head -5
   echo "--- /dev/shm:"
   ls -ld /dev/shm 2>&1 | head -1'