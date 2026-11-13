#!/bin/bash
# 1) linker64 hangi yollari ariyor? (strings ile KESIN)
# 2) /r/system/etc yazilabilir mi? (/system/etc RO)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) linker64 icindeki ld.config yollari ==="
A 'strings /system/bin/linker64 2>/dev/null | grep -iE "ld\.config|linkerconfig|LD_CONFIG" | head -15'
echo ""
echo "=== 2) linker64 LD_CONFIG_FILE destegi ==="
A 'strings /system/bin/linker64 2>/dev/null | grep -E "^LD_[A-Z_]+$" | head -10'
echo ""
echo "=== 3) /r/system/etc yazilabilir mi ==="
A 'touch /r/system/etc/.wtest 2>&1 && echo "YAZILABILIR" && rm -f /r/system/etc/.wtest || echo "YAZILAMAZ"'
echo ""
echo "=== 4) /system ve /r/system ayni mi ==="
A 'ls -ld /system /r/system 2>&1; echo "--- device:"; stat -c "%d:%i %n" /system/etc /r/system/etc 2>&1'