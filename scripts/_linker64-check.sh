#!/bin/bash
set -u
D=/root/harmony-build/boot/system-disk.img
echo "--- /system/bin/linker* ---"
dump.erofs --offset=1048576 --ls --path=/system/bin "$D" 2>/dev/null | grep -i 'linker'
echo ""
echo "--- qemu durumu ---"
ps -eo pid,etimes,comm | grep -i '[q]emu-system' || echo "QEMU bitti"