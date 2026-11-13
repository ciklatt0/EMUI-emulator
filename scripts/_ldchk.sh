#!/bin/bash
# Config gercekten PARSE ediliyor mu? Uyarilari say ve 64-bit bir
# ikiliyle dene (audioserver libmedia.so -> libandroidicu istiyor).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) config parse uyarisi sayisi ==="
A 'logcat -d 2>/dev/null | grep -c "failed to find generated linker configuration"'
echo ""
echo "=== 2) 64-bit ikili denemesi (audioserver) ==="
A '/system/bin/audioserver --help 2>&1 | head -3'
echo ""
echo "=== 3) [system] icindeki permitted satirlari (ilk 6) ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /permitted.paths/{print}' /linkerconfig/ld.config.txt | head -6"
echo ""
echo "=== 4) bos satir var mi (printf sonrasi) ==="
A "awk 'NR>=14 && NR<=22 {printf \"%d:[%s]\n\", NR, \$0}' /linkerconfig/ld.config.txt"
echo ""
echo "=== 5) search/permitted sayimlari ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /search\.paths/ && /apex/{n++} END{print \"search=\"n+0}' /linkerconfig/ld.config.txt"
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /permitted\.paths/ && /apex/{n++} END{print \"permitted=\"n+0}' /linkerconfig/ld.config.txt"