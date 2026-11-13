#!/bin/bash
# L5 aracini dener: baglanir, kabuk acar, bir komut calistirir.
# Kullanim: scripts/adb-test.sh [bekleme_sn]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WAIT="${1:-240}"

echo "=== 1) Emulator ayakta mi? ==="
if ! pgrep -f qemu-system >/dev/null 2>&1; then
  echo "  HAYIR. Once baslat:"
  echo "    wsl -d Ubuntu -u root -- env TMO=14400 HEADLESS=1 \\"
  echo "      bash $HERE/81-boot-zygote.sh"
  exit 1
fi
echo "  evet (pid $(pgrep -f qemu-system | tr '\n' ' '))"
echo ""

echo "=== 2) adb baglantisi (en fazla ${WAIT}s) ==="
bash "$HERE/adb.sh" --wait "$WAIT"
echo ""

echo "=== 3) KABUK KANITI ==="
bash "$HERE/adb.sh" sh 'echo "L5-CALISIYOR"; id; uname -m; getprop ro.product.model'
echo ""

echo "=== 4) Emulator kimlik ==="
bash "$HERE/adb.sh" sh 'getprop ro.build.version.release; getprop ro.build.display.id; getprop ro.build.version.security_patch'
echo ""

echo "=== 5) BagliMi (baglanti birkac kez denendi) ==="
bash "$HERE/adb.sh" --status