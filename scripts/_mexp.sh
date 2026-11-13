#!/bin/bash
# DOGRUDAN DENEY: mediaserver libandroidicu'yu bulabiliyor mu?
# permitted.paths satirimizi kaldirip tekrar dene.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) VARYANT A: permitted satirlarimiz VAR ==="
A 'grep -c "permitted.paths += /apex" /linkerconfig/ld.config.txt'
A '/system/bin/mediaserver --help 2>&1 | head -3'
echo ""
echo "=== 2) VARYANT B: permitted satirlarimiz YOK ==="
A '/bb/grep -v "^namespace.default.permitted.paths += /apex/" /linkerconfig/ld.config.txt > /tmp/ld.np2; cp /tmp/ld.np2 /linkerconfig/ld.config.txt'
A 'grep -c "permitted.paths += /apex" /linkerconfig/ld.config.txt'
A '/system/bin/mediaserver --help 2>&1 | head -3'
echo ""
echo "=== 3) VARYANT C: permitted OLMAYAN ama search PATE OLAN (dosyada ilk yazi) ==="
A 'grep -n "i18n" /linkerconfig/ld.config.txt | head -4'