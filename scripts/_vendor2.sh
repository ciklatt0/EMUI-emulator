#!/bin/bash
# [vendor] bolumu eklendi. CANNOT LINK gercekten azaldi mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) bolumler + vendor uyarisi ==="
grep -aE "vendor\] bolumu YOK|yamalandi: search|permitted\(" "$F" | tail -4 | sed 's/\[[^]]*\] //' | cut -c1-120
A 'grep -n "^\[" /linkerconfig/ld.config.txt'
echo ""
echo "=== 2) L5 ==="
A 'getprop ro.product.model; getprop init.svc.adbd'
echo ""
echo "=== 3) T0 sayaclar ==="
A 'echo "cannotlink=$(logcat -d 2>/dev/null | grep -c "CANNOT LINK") linkerwarn=$(logcat -d 2>/dev/null | grep -c "failed to find generated linker")"'
sleep 60
echo ""
echo "=== 4) T0+60 sayaclar (artiyor mu) ==="
A 'echo "cannotlink=$(logcat -d 2>/dev/null | grep -c "CANNOT LINK") linkerwarn=$(logcat -d 2>/dev/null | grep -c "failed to find generated linker")"'
echo ""
echo "=== 5) son CANNOT LINK turleri ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | tail -4 | sed "s/.*EXECUTABLE //;s/:.*//"'