#!/bin/bash
# QEMU user-mode networking varsayilanlari:
#   host 10.0.2.2, guest 10.0.2.15, DHCP -> 10.0.2.15
# 'hostfwd=tcp::5555-:5555' varsayilan olarak guest 10.0.2.15:5555'e
# yonlendirir. Biz eth0'a 10.0.2.15 veriyoruz -- dogru.
#
# AMA: guest kendi DHCP'siyle de IP almaya calisirsa cakisma olur.
# Bir de: SLIRP, hostfwd'yi guest'in ARPsine cevap vermesiyle
# degil, kendi sanal ARP tablosuyla yonetir. Yani IP dogruysa
# sorun yok.
#
# Burada olculecek: eth0 IP'si + ARP tablosu + QEMU'nun gordugu.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== guest eth0 ==="
grep -n '###   net: \[' "$F" | sed 's/\[[^]]*\] //' | tail -2 | cut -c1-230
echo ""
echo "=== ana ag gecidi (10.0.2.2) gorunuyor mu ==="
grep -n '### net: ' "$F" | sed 's/\[[^]]*\] //' | head -3 | cut -c1-230
echo ""
echo "=== QEMU komut satiri (hostfwd) ==="
grep -o 'hostfwd=[^ ]*' "$(dirname "$0")/81-boot-zygote.sh" | head -3
echo ""
echo "=== ana makinede 5555 ==="
ss -lntp 2>/dev/null | grep 5555 || echo "  dinleyici yok"