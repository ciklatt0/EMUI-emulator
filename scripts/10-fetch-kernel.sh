#!/usr/bin/env bash
# Amac: calisacak bir arm64 kernel Image'i indir.
#
# Neden Debian netboot? Resmi olarak arm64 hedefiyle uretilmis ve QEMU'da
# calisacak sekilde konfigure edilmis bir kernel. Ayrica virtio'nun built-in
# oldugunu dogruladik (91 referans) -> Faz 2'de disk surucusu icin de yeterli.
#
# NOT: Debian artik vmlinuz'u tek dosya olarak koymuyor; netboot.tar.gz icinde
# ./debian-installer/arm64/linux adiyla geliyor.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NETBOOT_URL="https://deb.debian.org/debian/dists/bookworm/main/installer-arm64/current/images/netboot/netboot.tar.gz"
OUT="$PROJECT/phase1/kernel/Image"

if [[ -f "$OUT" ]] && file "$OUT" | grep -q "Linux kernel ARM64"; then
  ok "kernel zaten yerinde: $OUT"
  exit 0
fi

fetch "$NETBOOT_URL" "$BUILD_DIR/netboot.tar.gz"

say "netboot paketi aciliyor, kernel cikariliyor"
tar -xzf "$BUILD_DIR/netboot.tar.gz" -C "$BUILD_DIR" ./debian-installer/arm64/linux
cp "$BUILD_DIR/debian-installer/arm64/linux" "$OUT"

if file "$OUT" | grep -q "Linux kernel ARM64"; then
  ok "format dogrulandi: $(file -b "$OUT")"
else
  die "beklenmeyen kernel formati: $(file -b "$OUT")"
fi

VIRTIO_N=$(strings "$OUT" | grep -ciE 'virtio' || true)
ok "kernel hazir: $OUT ($(du -h "$OUT" | cut -f1))  [virtio referansi: $VIRTIO_N]"