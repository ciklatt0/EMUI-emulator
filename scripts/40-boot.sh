#!/usr/bin/env bash
# Amac: QEMU'yu calistir.
#
#   40-boot.sh              -> interaktif (konsola dus)
#   40-boot.sh --test       -> 60 saniye calisip otomatik kapanir, log kaydeder
#
# Neden TCG? Host x86_64, guest arm64. Farkli mimari oldugu icin KVM/HVF
# kullanilamaz; QEMU'nun yazilim emulusyonu (TCG) zorunlu. Bu, WSL2 icinde
# calismaya da engel degildir.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need "$QEMU"

KERNEL="$PROJECT/phase1/kernel/Image"
INITRD="$PROJECT/phase1/out/initramfs.img"
LOG="$PROJECT/logs/boot.log"

[[ -f "$KERNEL" ]] || die "kernel yok: $KERNEL  (once 10-fetch-kernel.sh)"
[[ -f "$INITRD" ]] || die "initramfs yok: $INITRD  (once 30-make-initramfs.sh)"

MODE="interactive"; SECS=60
case "${1:-}" in
  --test) MODE="test" ;;
  --selftest-kernel) MODE="test"; SECS=10 ;;
esac

mkdir -p "$(dirname "$LOG")"

QEMU_ARGS=(
  -machine virt,gic-version=3,virtualization=on
  -cpu max
  -smp 4
  -m 2048
  -accel tcg,thread=multi
  -kernel "$KERNEL"
  -initrd "$INITRD"
  -append "console=ttyAMA0,115200 earlycon=pl011,0x9000000 rdinit=/init panic=-1"
  -display none
  -no-reboot
  # Aşama 1'de kullanmiyoruz ama Faz 2 icin yerine hazir:
  -device virtio-rng-device
  -device virtio-net-device,netdev=n0 -netdev user,id=n0
)

if [[ "$MODE" == "test" ]]; then
  say "QEMU test modu: ${SECS}s sonra otomatik kapanacak"
  say "TCG emulasyonu yavas olabilir, normal."
  timeout --signal=KILL "$SECS" "$QEMU" "${QEMU_ARGS[@]}" -monitor none \
      -serial "file:$LOG" </dev/null >/dev/null 2>&1 || true
  echo ""
  say "--- capture edilen seri cikti (son 40 satir) ---"
  tail -40 "$LOG" 2>/dev/null || echo "(log bos)"
  echo ""
  say "tam log: $LOG"
else
  say "interaktif mod - QEMU aciliyor. Cikis icin: Ctrl-A ardindan X"
  exec "$QEMU" "${QEMU_ARGS[@]}" -monitor stdio -serial stdio
fi