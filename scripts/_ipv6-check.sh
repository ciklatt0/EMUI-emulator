#!/bin/bash
# IPv6'nin gercekten yuklenmedigi dogrulanacak ve yeniden derleme
# maliyeti olculecek.
set -u
K=/root/harmony-build/linux-6.6
echo "=== 1) IPv6 config ==="
grep -E '^CONFIG_IPV6' "$K/.config" 2>/dev/null | head -12
echo ""
echo "=== 2) IPv6 modul dosyasi var mi? ==="
ls -la "$K/net/ipv6/ipv6.ko" 2>/dev/null || echo "  ipv6.ko YOK"
find /root/harmony-build/linux-6.6 -name 'ipv6.ko' 2>/dev/null | head -3
echo ""
echo "=== 3) derlenmis kernel: IPv6 gomulu mu? ==="
grep -c 'CONFIG_IPV6=y' "$K/.config" 2>/dev/null
echo ""
echo "=== 4) build betigi (sure tahmini icin) ==="
grep -n 'make -j\|JOBS=\|nproc' "$(dirname "$0")/80-build-kernel.sh" | head -5
echo ""
echo "=== 5) onceki kernel derleme suresi ==="
tail -3 /root/harmony-build/kernel-build.log 2>/dev/null | cut -c1-120
echo ""
echo "=== 6) IPv6'ya bagli diger ayarlar ==="
grep -E '^CONFIG_(IPV6_)' "$K/.config" 2>/dev/null | head -10