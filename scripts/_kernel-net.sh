#!/bin/bash
# QEMU -device virtio-net-device kullanıyor ama konukta eth0 yoksa
# hostfwd (tcp::5555-:5555) asla guest'e ulasamaz -> adb "offline".
# Kontrol: kernel yapilandirmasinda virtio-net ve net core var mi?
set -u
K=/root/harmony-build/linux-6.6
echo "--- .config: virtio / net ---"
grep -E '^CONFIG_(VIRTIO_NET|VIRTIO|VIRTIO_PCI|VIRTIO_MMIO|NET|INET|IPV6|PACKET|UNIX)=' "$K/.config" 2>/dev/null | head -20
echo ""
echo "--- .config: hepsi (VIRTIO*) ---"
grep -E '^CONFIG_VIRTIO' "$K/.config" 2>/dev/null | head -20
echo ""
echo "--- .config: ethernet sürücüleri ---"
grep -E '^CONFIG_(E1000|NE2K|VIRTIO_NET)' "$K/.config" 2>/dev/null | head -10