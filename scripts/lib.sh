#!/usr/bin/env bash
# Ortak ayarlar ve yardimcilar. Tum scriptler bunu source eder.
set -euo pipefail

# Proje koku. Windows calisma dizini WSL uzerinden /mnt/c ile gorunur.
PROJECT_WIN="$(wslpath -w "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 2>/dev/null || true)"
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Agir derleme isleri WSL'in yerel diskinde (OneDrive senkronizasyonu yavaslatir),
# yalnizca buyuk artifact'ler projeye kopyalanir.
BUILD_DIR="${BUILD_DIR:-/root/harmony-build}"

# Hedef mimari
export ARCH=arm64
export CROSS=aarch64-linux-gnu-
export CC="${CROSS}gcc"
export LD="${CROSS}ld"
export STRIP="${CROSS}strip"

# QEMU: guest arm64 <-> host x86_64 => KVM/HVF kullanilamaz, TCG zorunlu.
QEMU="${QEMU:-qemu-system-aarch64}"
QEMU_ACCEL="${QEMU_ACCEL:-tcg}"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  [uyari]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  [HATA]\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "gerekli komut bulunamadi: $1"; }

# Indir, zaten varsa tekrar indirme.
fetch() {
  local url="$1" dest="$2"
  if [[ -s "$dest" ]]; then
    ok "zaten var: $(basename "$dest")"
    return 0
  fi
  say "indiriliyor: $(basename "$dest")"
  mkdir -p "$(dirname "$dest")"
  # dot:giga -> her 1GB'de bir nokta; konsol kirlenmesin.
  wget -q --progress=dot:giga -O "$dest.part" "$url" || die "indirme basarisiz: $url"
  mv "$dest.part" "$dest"
  ok "$(basename "$dest") ($(du -h "$dest" | cut -f1))"
}

mkdir -p "$BUILD_DIR"