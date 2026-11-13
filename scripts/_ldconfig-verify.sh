#!/bin/bash
# linker config icin karar vermeden once 3 seyi dogrula:
#  1) /linkerconfig dizini firmware'de var mi, icinde ne var?
#  2) /apex/com.android.runtime/lib64/bionic gercekten orada mi?
#  3) /system/etc icinde ld.config.txt yoksa linker neye bakacak?
set -u
D=/root/harmony-build/boot/system-disk.img
OFF=1048576

echo "--- /system/linkerconfig ---"
dump.erofs --offset=$OFF --ls --path=/system/linkerconfig "$D" 2>/dev/null || echo "  (yok)"
echo ""
echo "--- /system/etc (tumu) ---"
dump.erofs --offset=$OFF --ls --path=/system/etc "$D" 2>/dev/null | head -30
echo ""
echo "--- runtime APEX bionic ---"
ls /root/harmony-build/apex/com.android.runtime/lib64/bionic/libc.so 2>/dev/null \
  && echo "  libc.so VAR" || echo "  (yerelde yok, diskte olabilir)"
echo ""
echo "--- logda linkerconfig izleri ---"
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -n 'linkerconfig\|ld.config' "$F" 2>/dev/null | head -10 || echo "  (yok)"