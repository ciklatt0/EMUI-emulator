#!/bin/bash
# ro.bootclasspath HICBIR prop dosyasinda yok. Bu, ART'nin boot
# classpath'i; zygote preload edemez. Firmware'de nerede?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) tum sistemde bootclasspath arama ==="
A 'grep -rl "bootclasspath" /system/etc /system/build.prop /vendor/build.prop /system/framework 2>/dev/null | head -6'
echo ""
echo "=== 2) tum prop dosyalarini listele ==="
A 'ls /system/etc/*.prop /vendor/etc/*.prop 2>/dev/null | head -8'
echo ""
echo "=== 3) default.prop / prop.default ==="
A 'ls -l /system/etc/default.prop /system/etc/prop.default /vendor/default.prop 2>&1 | head -4'
echo ""
echo "=== 4) build.prop satir sayisi ve ro. sayisi ==="
A 'wc -l /system/build.prop; grep -c "^ro\." /system/build.prop'
A 'head -20 /system/build.prop'
echo ""
echo "=== 5) framework/ icinde core-*.jar (bootclasspath adaylari) ==="
A 'ls /system/framework/ | grep -E "^core-|^android\.jar|framework\.jar" | head -6'