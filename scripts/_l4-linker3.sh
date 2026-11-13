#!/bin/bash
# linker64 su sirayi ariyor (strings):
#   /system/etc/ld.config.txt, .vndk_lite, /ld.config.txt,
#   .arm64.txt, /linkerconfig/ld.config.txt, /etc/ld.config.txt
#Bizim /linkerconfig/ld.config.txt 361 satir ve icinde art/lib64 VAR.
#Sorun: (a) dosya icerigi mi, (b) arama sirası mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== A) LD_CONFIG_FILE ile ZORLA bizim config ==="
A 'LD_CONFIG_FILE=/linkerconfig/ld.config.txt /system/bin/app_process64 --help 2>&1 | head -6'
echo ""
echo "=== B) sadece LD_LIBRARY_PATH ile ==="
A 'LD_LIBRARY_PATH=/apex/com.android.art/lib64:/system/lib64 /system/bin/app_process64 --help 2>&1 | head -6'
echo ""
echo "=== C) /linkerconfig/ld.config.txt ilk 3 satir + son satir ==="
A 'head -3 /linkerconfig/ld.config.txt; echo "..."; tail -3 /linkerconfig/ld.config.txt'
echo ""
echo "=== D) linker bu dosyayi gercekten ARIYOR mu (strace yerine: varlik) ==="
A 'ls -ld /linkerconfig; mount | grep linkerconfig'
echo ""
echo "=== E) system partition ro mu, /linkerconfig rw mi ==="
A 'cat /proc/mounts | grep -E "linkerconfig|/r |/system"'