#!/bin/bash
# ro.zygote build.prop icinde YOK ama getprop ro.zygote=zygote64_32
# donuyor. Ozellik baska bir yerden geliyor. Tum prop dosyalarini tara.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) tum prop.default / *.prop dosyalarinda ro.zygote ==="
A 'grep -rn "ro.zygote" /system/etc/prop.default /system/etc/*.prop /vendor/build.prop /system/build.prop /r/cust/build.prop 2>/dev/null | head -5'
echo ""
echo "=== 2) daha genis tarama (sadece okunabilir prop dosyalari) ==="
A 'for f in /system/etc/prop.default /vendor/build.prop /odm/etc/build.prop /cust/build.prop /r/system/etc/prop.default; do if [ -f $f ]; then v=$(grep "^ro.zygote" $f 2>/dev/null); echo "$f -> ${v:-YOK}"; fi; done'
echo ""
echo "=== 3) ro.hardware nerede ==="
A 'for f in /system/build.prop /vendor/build.prop /system/etc/prop.default; do v=$(grep "^ro.hardware=" $f 2>/dev/null); echo "$f -> ${v:-YOK}"; done'
echo ""
echo "=== 4) init.properties / default.prop ==="
A 'getprop | grep -E "\[ro\.(zygote|hardware|product\.device|product\.name)\]" '