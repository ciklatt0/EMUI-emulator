#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /default.prop (ramdisk'te olur) ==="
A 'ls -l /default.prop 2>&1; grep -n "bootclasspath" /default.prop 2>/dev/null'
echo ""
echo "=== 2) NOTICE.txt ve plat_property_contexts icindeki satirlar ==="
A 'grep -n "bootclasspath" /system/etc/NOTICE.txt 2>/dev/null | head -3'
A 'grep -n "bootclasspath" /system/etc/selinux/plat_property_contexts 2>/dev/null | head -3'
echo ""
echo "=== 3) tum sistem/prop altinda 'bootclasspath' gecen dosyalar ==="
A 'grep -rl "ro.bootclasspath" /system /vendor /odm /cust 2>/dev/null | head -8'
echo ""
echo "=== 4) boot-framework dosyalari ==="
A 'ls -l /system/framework/arm64/boot-framework.* 2>&1 | head -4'
echo ""
echo "=== 5) init bu ozelligi kendisi mi uretiyor (init.rc'de setprop) ==="
A 'grep -rn "bootclasspath" /system/etc/init/ /init.environ.rc 2>/dev/null | head -5'