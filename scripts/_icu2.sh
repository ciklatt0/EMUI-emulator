#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) [system] bolumundeki namespace.default.* satirlari ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /namespace.default/{print}' /linkerconfig/ld.config.txt | head -12"
echo ""
echo "=== 2) i18n arama yolunda MI ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /i18n/' /linkerconfig/ld.config.txt | head -3"
echo ""
echo "=== 3) permitted.paths icinde i18n var MI (kritik) ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /permitted.paths/{print}' /linkerconfig/ld.config.txt | head -3"
echo ""
echo "=== 4) dir.* satirlari (system bolumu) ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /^dir\./{print}' /linkerconfig/ld.config.txt | head -8"