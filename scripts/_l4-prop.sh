#!/bin/bash
# rclog aninda (boot'un 8-13. saniyesi) /system/build.prop okunamadi.
# Dosya konakta VAR ama zamanlama geregi erisilemiyor.
# Konukta simdi (gecikmeli) okunabiliyor mu?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) build.prop yollari ==="
A 'ls -l /system/build.prop /r/system/build.prop /r/etc/build.prop 2>&1'
echo ""
echo "=== 2) degerler orada mi ==="
A 'grep -E "^ro\.zygote=|^ro\.hardware=|^ro\.product\.device=" /system/build.prop 2>&1'
echo ""
echo "=== 3) supervisor /system'i ne zaman mount ediyor ==="
grep -nE "build.prop|/r/system|system mount|mount.*/r" "$(dirname "$0")/81-boot-zygote.sh" | head -12
echo ""
echo "=== 4) HOST tarafinda build.prop'i okudugumuz yer ==="
grep -nE "build\.prop" "$(dirname "$0")/81-boot-zygote.sh" | head -12