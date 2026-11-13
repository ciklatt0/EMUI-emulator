#!/bin/bash
# ART calistirilirken: "Error finding namespace of apex:
# no namespace called com_android_art"
# Bu, linker config'te namespace'in DECLARE edildigi ama
# link.default ile default namespace'e BAGLANMADIGI anlamina
# gelir. Kontrol edelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) link.default satirlari ==="
A 'grep -n "^link\." /linkerconfig/ld.config.txt | head -12'
echo ""
echo "=== 2) com_android_art namespace tanimli MI ==="
A 'grep -c "^namespace.com_android_art" /linkerconfig/ld.config.txt
   echo "--- satirlar:"
   grep -n "^namespace.com_android_art" /linkerconfig/ld.config.txt | head -6 | cut -c1-90'
echo ""
echo "=== 3) link.default icinde com_android_art VAR MI ==="
A 'L=$(grep "^link.default" /linkerconfig/ld.config.txt | /bb/head -1)
   echo "  $L" | cut -c1-250
   echo "  --- icinde com_android_art: $(echo "$L" | grep -c com_android_art)"'
echo ""
echo "=== 4) STOK configte (bizim stash'imiz) ne vardi ==="
A 'grep -n "^link.default" /bb/nb/ld.stock 2>/dev/null | /bb/head -3 | cut -c1-200
   echo "--- stokta com_android_art namespace: $(grep -c "^namespace.com_android_art" /bb/nb/ld.stock 2>/dev/null)"'
echo ""
echo "=== 5) diger apex namespace'leri link.default'da MI (kontrol) ==="
A 'for n in com_android_runtime com_android_media com_android_i18n com_android_adbd; do
   L=$(grep "^link.default" /linkerconfig/ld.config.txt | /bb/head -1)
   printf "  %-22s tanimli=%s  defaulta_bagli=%s\n" "$n" \
     "$(grep -c "^namespace.$n" /linkerconfig/ld.config.txt)" \
     "$(echo "$L" | grep -c $n)"
 done'