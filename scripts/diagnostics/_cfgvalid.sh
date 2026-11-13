#!/bin/bash
# HIPOTEZ: link.public veya link.default icinde TANIMSIZ bir
# namespace adi varsa, bionic config'i TAM OLARAK REDDEDIP
# dahili varsayilana duser. Bu, "4 farkli config -> hep ayni
# hata" olusunu TAM OLARAK ACIKLAR.
#
# DOGRULAMA: config'te
#   a) hangi namespace'ler TANIMLI
#   b) link.default / link.public hangi adlari referans ediyor
#   c) fark = tanimsiz referans (config reddi sebebi)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'C=/linkerconfig/ld.config.txt
   /bb/grep -oE "^namespace\.[A-Za-z0-9_]+\.(isolated|search|permitted)" "$C" \
     | /bb/sed "s/^namespace\.//; s/\..*$//" | /bb/sort -u > /tmp/def.txt
   echo "  TANIMLI namespace sayisi : $(/bb/wc -l < /tmp/def.txt)"
   echo "  --- ilk 12:"
   /bb/head -12 /tmp/def.txt | /bb/tr "\n" " " ; echo
   echo ""
   for K in link.default link.public; do
     L=$(/bb/grep "^$K" "$C" | /bb/head -1)
     echo "  $K referansi:"
     /bb/echo "$L" | /bb/sed "s/^$K *= *//" | /bb/tr "," "\n" | /bb/sed "s/^ *//; s/ *$//" \
       | /bb/grep -v "^$" > /tmp/ref.txt
     echo "    adet: $(/bb/wc -l < /tmp/ref.txt)"
     echo "    --- TANIMSIZ OLANLAR (config reddi sebebi):"
     /bb/comm -23 /tmp/ref.txt /tmp/def.txt | /bb/sed "s/^/      /"
   done
   echo ""
   echo "  === configin TAMAMINDA baska hata olabilir mi ==="
   echo "  --- section sayisi: $(/bb/grep -c "^\[" "$C")"
   echo "  --- [apex] bolumu:  $(/bb/grep -c "^\[apex\]" "$C")"'
echo ""
echo "=== ABORT SEBEBINI TAM GOR (neden oluyor?) ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -nE "dalvikvm64|F/runtime|Check failed|abort" | grep -v "avc:" | /bb/head -8 | cut -c1-200
   echo "  --- son 5 dalvikvm64 satiri:"
   logcat -d -b all -v time 2>/dev/null | grep "dalvikvm64" | grep -v "avc:" | /bb/tail -5 | cut -c1-200'
echo ""
echo "=== abort stack'in en ust kareleri (kim cagriyor) ==="
A 'logcat -d -b all 2>/dev/null | grep -oE "/apex/[a-z.]+/lib64/lib[a-z]+\.so \(art::[A-Za-z_:]+" | /bb/sort -u | /bb/head -12'