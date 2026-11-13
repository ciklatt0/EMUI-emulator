#!/bin/bash
# Ana init.rc nerede? Bizim overlay (/overlay-rc) onu iceriyor mu?
# 'ctl.start zygote' basarisizligi ancak master rc'deki
# 'import /system/etc/init/hw/init.zygote*.rc' satirinin
# YORUMLANDIGI ya da dosyanin KAYBOLMASI ile olur.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /overlay-rc icerigi (bizim kaynak) ==="
A 'ls -la /overlay-rc 2>&1 | head -20'
echo ""
echo "=== 2) /overlay-rc alt dizinler ==="
A 'ls /overlay-rc/* 2>&1 | head -20'
echo ""
echo "=== 3) master init.rc arama ==="
A 'for d in /system/etc/init /r/system/etc/init /overlay-rc; do echo "[$d]"; ls $d/init.rc 2>&1; done'
echo ""
echo "=== 4) tum init.svc.* listesi (zygote var mi?) ==="
A 'getprop | grep "^init.svc" | wc -l'
A 'getprop | grep -i "zygote" | head -10'
echo ""
echo "=== 5) calisan servisler (running) ==="
A 'getprop | grep "^init.svc" | grep running | head -20'