#!/usr/bin/env bash
# Emulasyonu GORUNUR sekilde baslat: Windows Terminal penceresi acilir ve
# icinde QEMU'nun canli seri konsole akisi gorulur.
#
# Neden ayri bir yol? Grafik pencere (virtio-gpu -> /dev/fb0) yeni kernel
# gerektiriyor ve konuk tarafta framebuffer sadece BOOT LOGUNU gosterir.
# Asıl degerli olan sey canli metin akisi -- onu dogrudan terminale
# yaziyoruz. Log dosyasi da ayni anda dolmaya devam ediyor.
#
# Kullanim:  scripts/82-boot-window.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL="$HERE/../phase1/kernel/Image"
DISK="/root/harmony-build/boot/system-disk.img"
OUT="$HERE/../phase1/out/initramfs-boot.img"
LOG="$HERE/../logs/boot-zygote.log"
ROOT="/root/harmony-build/initramfs-boot"
BUSYBOX="$HERE/../phase1/rootfs/bin/busybox"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

[[ -f "$KERNEL" ]] || { echo "HATA: kernel yok: $KERNEL"; exit 1; }
[[ -f "$OUT"    ]] || { echo "HATA: initramfs yok (once 81-boot-zygote.sh calistir)"; exit 1; }
[[ -f "$DISK"   ]] || { echo "HATA: disk yok (once 80-build-bootdisk.sh calistir)"; exit 1; }

mkdir -p "$(dirname "$LOG")"

say "canli konsol aciliyor (yeni terminal penceresi)"
echo "  kapatmak icin: pencereyi kapat veya Ctrl+C"
echo "  ayni akis dosyada da: $LOG"
echo ""

# Seri konsole stdio'ya bagliyoruz VE ayni anda dosyaya da yaziyoruz.
# QEMU'nun chardev'i 'file' ile 'stdio' ayni anda olamaz; onun yerine
# stdio'yu 'tee' ile dosyaya akitiriz.
exec timeout --signal=KILL "${TMO:-1200}" bash -c '
  qemu-system-aarch64 \
    -machine virt,gic-version=3,virtualization=on \
    -cpu max -smp 4 -m 4096 \
    -accel tcg,thread=multi \
    -kernel '"$KERNEL"' -initrd '"$OUT"' \
    -append "console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7" \
    -display none -serial mon:stdio \
    -drive file='"$DISK"',if=none,format=raw,id=sysdisk,cache=unsafe \
    -device virtio-blk-device,drive=sysdisk,bootindex=1 \
    -device virtio-rng-device \
    -device virtio-net-device,netdev=n0 -netdev user,id=n0 \
    2>&1 | tee -a '"$LOG"'
'
