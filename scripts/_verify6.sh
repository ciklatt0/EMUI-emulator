#!/bin/bash
# init'in linkerconfig'i devre disi; config tek kaynaktan geliyor.
# CANNOT LINK sayisi sifirlanmali.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) rclog linkerconfig yorumlamasi ==="
grep -aE "linkerconfig|SIFIRLADI|yamalandi: search|apex/etc" "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-130
echo ""
echo "=== 2) linker uyarisi (0 olmali) ==="
A 'logcat -d 2>/dev/null | grep -c "failed to find generated linker"'
echo ""
echo "=== 3) CANNOT LINK sayisi ve turleri ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | sed "s/.*EXECUTABLE //;s/:.*//" | sort | uniq -c | sort -rn | head -6'
echo ""
echo "=== 4) zygote + system_server ==="
A 'getprop init.svc.zygote; ps -A 2>/dev/null | grep -iE "zygote|system_server" | head -5'
echo ""
echo "=== 5) calisan servisler ==="
A 'getprop | grep "\[init.svc" | grep -c running'
A 'getprop | grep "\[init.svc" | grep running | head -18'