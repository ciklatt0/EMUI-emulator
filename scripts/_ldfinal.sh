#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) config gercekten yerinde mi ==="
A 'ls -l /linkerconfig/ld.config.txt; grep -c apex /linkerconfig/ld.config.txt'
echo ""
echo "=== 2) bionic (libc.so) yolda MI ==="
A 'grep -n "bionic" /linkerconfig/ld.config.txt | head -4'
echo ""
echo "=== 3) [system] arama yollarinin TAM listesi (ilk 12) ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /search\.paths/' /linkerconfig/ld.config.txt | head -12"
echo ""
echo "=== 4) libc.so gercekten nerede ==="
A 'ls -l /apex/com.android.runtime/lib64/bionic/libc.so 2>&1 | head -2'
echo ""
echo "=== 5) DOGRUDAN TEST: init bu config ile baglaniyor mu ==="
A '/system/bin/ueventd --help 2>&1 | head -2'
echo ""
echo "=== 6) apex/etc kopyalari ==="
A 'ls /apex/*/etc/ld.config.txt 2>/dev/null | head -5; ls /apex/*/etc/ld.config.txt 2>/dev/null | wc -l'
echo ""
echo "=== 7) linkercconfig uyarisi sayisi ==="
A 'logcat -d 2>/dev/null | grep -c "failed to find generated linker"'