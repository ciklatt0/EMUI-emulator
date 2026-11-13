#!/usr/bin/env bash
# Faz 2: sanal disk surucusu testi.
#
# Soru: Faz 1'de root bellekteydi (initramfs), disk kullanilmadi. Simdi
# system.img'yi disk olarak baglamamiz gerekiyor. Bunun icin once su
# bilinmeli: kernel'de virtio_blk GOMULU mu, yoksa modul mu?
#
# Cevap hangisi olursa olsun yol bellidir; sadece yapimiz degisir:
#   gomulu  -> kernel ile birlikte gelir, initramfs'e koymaya gerek yok
#   modul   -> modul dosyasini initramfs'e koymamiz gerekir
#
# Test: kucuk bir disk yaratip virtio-blk olarak ekliyoruz. Mevcut /init
# zaten /sys/block listesini basiyor, yani cevap logda gorunecek.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need "$QEMU"; need qemu-img

KERNEL="$PROJECT/phase1/kernel/Image"
INITRD="$PROJECT/phase1/out/initramfs.img"
DISK="$BUILD_DIR/probe-disk.img"
LOG="$PROJECT/logs/phase2-disk.log"

[[ -f "$KERNEL" && -f "$INITRD" ]] || die "once run-all.sh calistir"

[[ -f "$DISK" ]] || qemu-img create -f raw "$DISK" 256M >/dev/null
ok "disk yaratildi: $(du -h "$DISK" | cut -f1)"

mkdir -p "$(dirname "$LOG")"
say "QEMU'ya virtio-blk baglanip 45 saniye calistiriliyor"

timeout --signal=KILL 45 "$QEMU" \
  -machine virt,gic-version=3,virtualization=on \
  -cpu max -smp 4 -m 2048 \
  -accel tcg,thread=multi \
  -kernel "$KERNEL" -initrd "$INITRD" \
  -append "console=ttyAMA0,115200 rdinit=/init panic=-1" \
  -display none -no-reboot -monitor none \
  -drive "file=$DISK,if=none,format=raw,id=disk0" \
  -device virtio-blk-device,drive=disk0 \
  -serial "file:$LOG" </dev/null >/dev/null 2>&1 || true

echo ""
if grep -qE '^vda' "$LOG" 2>/dev/null; then
  ok "virtio_blk KERNEL'E GOMULU (/dev/vda gorundu)"
  say "-> disk sistemi kullanmaya hazir, Faz 2'ye gecebiliriz"
elif grep -qi 'virtio_blk' "$LOG" 2>/dev/null; then
  warn "virtio_blk kernel'de gorunuyor ama /dev/vda olusmadi"
else
  warn "virtio_blk modul olarak yuklenmis olabilir (kernel'de gomulu degil)"
fi

echo ""
say "--- /sys/block bolumu ---"
sed -n '/sanal disk suruculeri/,/seri konsol/p' "$LOG" 2>/dev/null | head -15
echo ""
say "--- kernel'daki virtio izleri ---"
grep -iE 'virtio|vda' "$LOG" 2>/dev/null | head -15
echo ""
say "tam log: $LOG"