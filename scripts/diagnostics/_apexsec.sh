#!/bin/bash
# dltrace izi: ART, /apex/com.android.art/lib64/ altindaki
# libnativehelper.so, libartbase.so, libartpalette-system.so
# dosyalarini EXT (android_dlopen_ext) ile yukluyor.
# Linker cozumlenen yolu gorup /apex/<ad>/ altinda oldugunu
# fark edince namespace turetir; "[apex]" bolumu olmadigi icin
# com_android_art'i bulamaz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) config'te [apex] bolumu VAR MI ==="
A 'grep -c "^\[apex\]" /linkerconfig/ld.config.txt
   echo "--- apex.* satirlari:"
   grep -c "^apex\." /linkerconfig/ld.config.txt
   grep -n "^\[apex\]\|^apex\." /linkerconfig/ld.config.txt | head -6 | cut -c1-90'
echo ""
echo "=== 2) bolum listesi ==="
A 'grep -n "^\[" /linkerconfig/ld.config.txt | head -12'
echo ""
echo "=== 3) AOSP'de [apex] bolumu ne icermeli (ornek) ==="
A 'echo "  [apex]"
   echo "  apex.com.android.art = /apex/com.android.art"
   echo "  apex.com.android.runtime = /apex/com.android.runtime"
   echo "  ... her apex icin bir satir"'
echo ""
echo "=== 4) APEX'lerimiz ==="
A '/bb/ls /apex/ 2>/dev/null | grep "^com\." | /bb/head -25 | /bb/tr "\n" " "'
echo ""
echo ""
echo "=== 5) kanit: libnativehelper.so gercekten APEX altinda MI ==="
A 'ls -l /apex/com.android.art/lib64/libnativehelper.so /apex/com.android.art/lib64/libartbase.so 2>&1 | head -3'
echo ""
echo "=== 6) config'te apex yollari var MI (arama yolu olarak) ==="
A 'grep -c "apex/com.android.art" /linkerconfig/ld.config.txt'