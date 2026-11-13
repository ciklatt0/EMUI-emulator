#!/bin/bash
# BULGUN SONUCU: [apex] bolumu 23 satir yazildi ama
# link.default/link.public BOSLUKLA ayrilmis (virgulle degil):
#     link.default = default,system com_android_adbd com_android_art ...
# bionic virgulle ayirir -> "default,system" tek ad, gerisi yoksayilir.
# AYRICA config'te sadece 17 namespace TANIMLI; link.default
# icinde tanimsiz ad olursa linker config'i TAMAMEN REDDEDER.
# Ikisini de olculelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'C=/linkerconfig/ld.config.txt
   echo "=== 1) link.default satirinin TAMAMI ==="
   /bb/grep "^link.default" "$C" | /bb/head -1 | cut -c1-400
   echo ""
   echo "=== 2) link.public satirinin TAMAMI ==="
   /bb/grep "^link.public" "$C" | /bb/head -1 | cut -c1-400
   echo ""
   echo "=== 3) VIRGUL SAYISI (dogru olsa cok olmali) ==="
   D=$(/bb/grep "^link.default" "$C" | /bb/head -1)
   echo "  virgul: $(/bb/echo "$D" | /bb/tr -cd "," | /bb/wc -c)"
   echo "  bosluk: $(/bb/echo "$D" | /bb/tr -cd " " | /bb/wc -c)"
   echo ""
   echo "=== 4) configteki TUM tanimli namespace ler ==="
   /bb/grep -oE "^namespace\.[A-Za-z0-9_]+\.(isolated|search|permitted)" "$C" \
     | /bb/sed "s/^namespace\.//; s/\..*$//" | /bb/sort -u | /bb/tr "\n" " "
   echo ""
   echo ""
   echo "=== 5) [apex] bolumundeki APEX adlari ==="
   /bb/grep "^apex\." "$C" | /bb/head -25 | /bb/tr "\n" " " | cut -c1-400'