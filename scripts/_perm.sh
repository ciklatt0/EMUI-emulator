#!/bin/bash
# IKI KANIT BIRLESIYOR:
#   dalvikvm64  -> libart.so'yu DOGRUKAN bagli  -> calisiyor
#   app_process64 -> libart.so'yu dlopen ile   -> HIC yuklemiyor
# dlopen, bionic'te permitted.paths BEYAZ LISTESINE tabidir.
# [system] bolumunde /apex/com.android.art/lib64
#   search.paths'te VARSA ama permitted.paths'te YOKSA ->
#   dlopen("libart.so") SESSIZCE basarisiz olur.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) [system] bolumunde art/lib64: search VE permitted ==="
A 'S=$(awk "/^\[system\]/{s=1;next} /^\\[/{s=0} s && /namespace.default.search.paths/" /linkerconfig/ld.config.txt)
   P=$(awk "/^\[system\]/{s=1;next} /^\\[/{s=0} s && /namespace.default.permitted.paths/" /linkerconfig/ld.config.txt)
   echo "  search    icinde art/lib64   : $(echo "$S" | tr ":" "\n" | grep -c "com.android.art/lib64")"
   echo "  permitted icinde art/lib64   : $(echo "$P" | tr ":" "\n" | grep -c "com.android.art/lib64")"
   echo "  permitted satirinin TAMAMI:"
   echo "$P" | tr ":" "\n" | sed "s/^/    /" | head -30'
echo ""
echo "=== 2) tum bolumlerde art/lib64 icinik ==="
A 'awk "/^\[/{b=\$0} /com.android.art\/lib64/ && /search|permitted/{print b, \$1}" /linkerconfig/ld.config.txt | head -12'
echo ""
echo "=== 3) permitted.paths satirlari (hepsi) ==="
A 'grep -n "permitted.paths" /linkerconfig/ld.config.txt | cut -c1-120'