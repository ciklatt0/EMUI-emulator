#!/bin/bash
G=/root/harmony-build/initramfs-boot/bb/supervise
echo "--- uretilen supervise: adbd_ldconfig ---"
awk '/^adbd_ldconfig\(\)/,/^}/' "$G"
echo ""
echo "--- ensure_adbd ---"
awk '/^ensure_adbd\(\)/,/^}/' "$G"