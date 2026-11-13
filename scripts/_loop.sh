#!/bin/bash
# mount none /linkerconfig/bootstrap /linkerconfig bind rec
# -> OZYINULEMELI (recursive) bind. /linkerconfig kendi altina
# baglaniyor. Sonuc: sonsuz dongu; bazi namespace'lerde ELOOP.
# Dosya "var" gorunur ama linker acamaz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) bootstrap/bootstrap zinciri var mi (oyinelemeli isaret) ==="
A 'ls -d /linkerconfig/bootstrap/bootstrap 2>&1; ls -d /linkerconfig/bootstrap/bootstrap/bootstrap 2>&1'
echo ""
echo "=== 2) ELOOP kaniti: cat ile dogrudan okuma ==="
A 'head -1 /linkerconfig/ld.config.txt 2>&1; echo "RC=$?"'
echo ""
echo "=== 3) farkli namespace dene (vendor subcontext benzeri) ==="
A 'unshare -m /bin/busybox head -1 /linkerconfig/ld.config.txt 2>&1 || echo "unshare yok/yenemedi"'
echo ""
echo "=== 4) mount zinciri ==="
A 'cat /proc/mounts | grep -A1 -B1 linkerconfig | head -10'
echo ""
echo "=== 5) bootstrap/default icerik ==="
A 'ls -l /linkerconfig/bootstrap/ /linkerconfig/default/ 2>&1 | head -10'