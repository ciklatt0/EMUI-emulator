#!/usr/bin/env bash
# Kutuphane envanterini cikarir.
#
# DIKKAT: Tarayici dogrudan calistirilirsa 0 sonuc doner. Sebep: WSL2 yasam
# dongusu -- yeni bir `wsl` komutu yeni bir VM baslatir ve onceki oturumdaki
# mount'lar kaybolur. Bu yuzden once agacin AYNI oturumda kuruldugunu
# garantiliyoruz, sonra taramayi yapiyoruz.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="/root/harmony-build/tree"

if ! mountpoint -q "$TREE/rootfs" 2>/dev/null; then
  echo "[+] agac kuruluyor (WSL mount'lari sifirlanmis)"
  bash "$HERE/100-usable-rootfs.sh" >/dev/null 2>&1
fi

if ! mountpoint -q "$TREE/rootfs" 2>/dev/null; then
  echo "HATA: agac kurulamadi. Manuel deneyin:"
  echo "  bash $HERE/100-usable-rootfs.sh"
  exit 1
fi

exec python3 "$HERE/120-library-scan.py"