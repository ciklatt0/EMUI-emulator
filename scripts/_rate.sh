#!/bin/bash
# CANNOT LINK sayisi ARTIYOR MU? Iki olcum arasinda fark varsa
# sorun devam ediyor; fark yoksa COZULDU.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== T0 ==="
A 'echo "cannotlink=$(logcat -d 2>/dev/null | grep -c "CANNOT LINK")  linkerwarn=$(logcat -d 2>/dev/null | grep -c "failed to find generated linker")  ueventd=$(getprop init.svc.ueventd)"'
sleep 60
echo ""
echo "=== T0 + 60 sn ==="
A 'echo "cannotlink=$(logcat -d 2>/dev/null | grep -c "CANNOT LINK")  linkerwarn=$(logcat -d 2>/dev/null | grep -c "failed to find generated linker")  ueventd=$(getprop init.svc.ueventd)"'
echo ""
echo "=== config hala saglam mi ==="
A 'ls -l /linkerconfig/ld.config.txt; grep -c apex /linkerconfig/ld.config.txt'
echo ""
echo "=== son CANNOT LINK satirlari ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | tail -4'