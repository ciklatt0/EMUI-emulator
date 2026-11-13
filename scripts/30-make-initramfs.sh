#!/usr/bin/env bash
# Amac: initramfs.img uret. Root olarak calisacak, tamamen bellekte olan
# bir userspace. Amacimiz disk surucusu hic kullanmadan TCG + serial console
# + arm64 userspace calistigini kanitlamak.
#
# /init, kanit raporu uretir: hangi sozgun calisiyor, hangi arayuzler var,
# konsolun okunup okunamadigi vb. Hata ayiklamada ilk bakacagin yer burasi olacak.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$BUILD_DIR/initramfs"
OUT="$PROJECT/phase1/out/initramfs.img"
BUSYBOX="$PROJECT/phase1/rootfs/bin/busybox"

[[ -x "$BUSYBOX" ]] || die "once 20-build-busybox.sh calistir"

say "initramfs agaci hazirlaniyor"
rm -rf "$ROOT"; mkdir -p "$ROOT"/{bin,sbin,dev,proc,sys,tmp,root}

cp "$BUSYBOX" "$ROOT/bin/busybox"
# busybox, init disindaki tum araclar icin sembolik linkler bekler.
# /init'in kullandigi her arac burada olmali, yoksa "not found" verir.
for applet in sh ls cat head tail mount umount mkdir rmdir ps dmesg poweroff reboot \
               sleep grep echo uname df free ln cp mv rm touch du date env; do
  ln -sf /bin/busybox "$ROOT/bin/$applet"
done

cat >"$ROOT/init" <<'INIT_EOF'
#!/bin/sh
# ---- HarmonyOS emulator / Faz 1 kanit /init ----
export PATH=/bin:/sbin
/bin/mount -t proc     proc     /proc
/bin/mount -t sysfs    sysfs    /sys
/bin/mount -t devtmpfs devtmpfs /dev 2>/dev/null
/bin/mount -t tmpfs    tmpfs    /tmp

banner() {
  echo ""
  echo "=============================================="
  echo "  HARMONYOS EMULATOR - FAZ 1 KANITI"
  echo "=============================================="
  echo ""
}

banner
echo "--- mimari ---"
echo "  uname -m : $(uname -m)"
echo "  uname -r : $(uname -r)"
echo ""
echo "--- bellek ---"
free -m 2>/dev/null || echo "  (free yok)"
echo ""
echo "--- QEMU cihazlari (/sys/bus/platform/devices) ---"
ls /sys/bus/platform/devices 2>/dev/null | grep -v '^cpus$' | head -40 || echo "  yok"
echo ""
echo "--- sanal disk suruculeri ---"
ls /sys/block 2>/dev/null || echo "  /sys/block yok (bu fazda beklenen)"
echo ""
echo "--- seri konsol ---"
if [ -c /dev/console ]; then
  echo "  /dev/console : VAR"
else
  echo "  /dev/console : YOK  <-- console= kernel cmdline hatasi olabilir"
fi
echo ""
echo "=============================================="
echo "  TCG + arm64 userspace + serial console CALISIYOR"
echo "  Bu, ilk boot basarisidir."
echo "=============================================="
echo ""
echo "Kanit: emulator omurgasi ayakta. Sonraki adim -> Faz 2 (virtio disk + HAL)."
echo ""
echo "Shell'e dusmek icin Enter'a bas. (poweroff ile kapat)"
echo ""

# Etkilesimli shell. stdin yoksa kernel girmezse sonsuz beklemesin.
if [ -t 0 ]; then
  exec /bin/sh
else
  exec /bin/sh < /dev/console > /dev/console 2>&1
fi
INIT_EOF
chmod +x "$ROOT/init"

say "cpio paketleniyor (gzip)"
mkdir -p "$(dirname "$OUT")"
( cd "$ROOT" && find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -1 ) > "$OUT"
ok "initramfs: $OUT ($(du -h "$OUT" | cut -f1))"