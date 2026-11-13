#!/bin/bash
# Eski QEMU'yu kapat ve kilidi/loglari temizle. Sonra yeni kosu icin
# hazir.
echo "--- onceki qemu ---"
ps -eo pid,etimes,comm | grep -i '[q]emu-system' || echo "  yok"
pkill -9 -f qemu-system-aarch64 2>/dev/null
sleep 2
pkill -9 -f qemu-system-aar 2>/dev/null
sleep 1
echo "--- sonra ---"
ps -eo pid,comm | grep -i '[q]emu-system' || echo "  temiz"
rm -f /tmp/harmony-emulator.lock
rm -f /tmp/harmony-emulator.*.log
echo "  log sayisi: $(ls /tmp/harmony-emulator.*.log 2>/dev/null | wc -l)"