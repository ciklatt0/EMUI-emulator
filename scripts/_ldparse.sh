#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) [system] bolumunun BASI (search.paths eklemesi) ==="
A "grep -n '^\[system\]' /linkerconfig/ld.config.txt | head -2"
A "sed -n '1,30p' /linkerconfig/ld.config.txt | cat -n | head -32"
echo ""
echo "=== 2) permitted.paths satirlari ve bolumleri ==="
A "grep -n 'permitted.paths' /linkerconfig/ld.config.txt | head -8"
A "grep -n '^\[' /linkerconfig/ld.config.txt | head -6"