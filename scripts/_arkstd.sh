#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) arkstdlib.abc nerede (ark'in varsayilan boot dosyasi) ==="
A 'find /system /apex /vendor /data -name "*arkstdlib*" 2>/dev/null | head -5
   echo "  --- pandastdlib dizini:"
   find /system /apex -type d -name "pandastdlib" 2>/dev/null | head -3
   echo "  --- tum .abc sayisi:"
   find /system -name "*.abc" 2>/dev/null | wc -l'
echo ""
echo "=== 2) /system/lib64/ark icerigi ==="
A 'ls -l /system/lib64/ark/ 2>&1 | head -12'
echo ""
echo "=== 3) framework.abc VAR MI (ana framework Ark surumu) ==="
A 'ls -l /system/framework/framework.* 2>&1 | head -5
   echo "  --- .abc listesi (tam):"
   ls /system/framework/*.abc 2>/dev/null | /bb/head -20'
echo ""
echo "=== 4) libarkruntime.so gercekten VM mi (dlopen testi) ==="
A 'echo "  boyut: $(ls -l /system/lib64/ark/libarkruntime.so 2>/dev/null | tr -s " " | cut -d" " -f5)"
   echo "  --- configte bu yol var MI:"
   grep -c "lib64/ark" /linkerconfig/ld.config.txt
   echo "  --- linker bu kutuphaneyi cozebiliyor mu:"
   /system/bin/linker64 --list /system/lib64/ark/libarkruntime.so 2>&1 | head -6'