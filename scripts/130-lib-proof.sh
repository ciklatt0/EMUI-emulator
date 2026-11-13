#!/usr/bin/env bash
# Huawei kutuphanelerini NDK/Bionic ile derlenmis bir programdan CAGIRIR.
#
# Neden NDK? Onceki deneme glibc ile derlenmisti ve "qemu: signal 5" aldi.
# Sebep yapisaldi: glibc'nin ld.so'su Bionic kutuphanelerini yukleyemez --
# Android kutuphanesini yalnizca Android'in kendi linkeri (linker64) yukler.
# NDK ile derlenen program da Bionic olur, ikisi ayni ortamda yurur.
#
# Hedef API 31: cihazimizin ro.build.version.sdk degeri 31 (Android 12).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="/root/harmony-build/tree"
NDK=$(ls -d /root/harmony-build/ndk/android-ndk-* 2>/dev/null | head -1)
CC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
API=31
BUILD="/tmp/ndk-proof"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [ok]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m  [uyari]\033[0m %s\n' "$*"; }

[ -x "$CC" ] || { echo "HATA: NDK clang bulunamadi: $CC"; exit 1; }
say "NDK: $(basename "$NDK")   API $API"

mountpoint -q "$TREE/rootfs" 2>/dev/null || bash "$HERE/100-usable-rootfs.sh" >/dev/null 2>&1
mountpoint -q "$TREE/rootfs" 2>/dev/null || { echo "HATA: agac kurulamadi"; exit 1; }

say "derleniyor (Bionic, aarch64)"
mkdir -p "$BUILD"
"$CC" --target=aarch64-linux-android$API --sysroot="$SYSROOT" \
      -O2 -o "$BUILD/libproof" "$HERE/130-lib-proof.c" -ldl 2>&1 | head -10
[ -f "$BUILD/libproof" ] || { echo "HATA: derleme basarisiz"; exit 1; }
ok "derlendi: $(stat -c %s "$BUILD/libproof") bayt"
echo "        ELF: $(file -b "$BUILD/libproof" | cut -d, -f1,2)"
echo "        interpreter: $(aarch64-linux-gnu-readelf -l "$BUILD/libproof" 2>/dev/null | grep -oE '/[^]]*linker[^]]*' | head -1)"

mkdir -p "$TREE/tmp"
cp "$BUILD/libproof" "$TREE/tmp/libproof"
chmod +x "$TREE/tmp/libproof"

say "calistiriliyor"
echo ""
# LD_LIBRARY_PATH sart: dlopen ile yuklenen kutuphanenin bagimliliklari ana
# programin namespace'ini miras almaz. Profil 100-usable-rootfs.sh tarafindan
# uretilir.
ENVF="/harmony-env.sh"
echo "--- (1) Android linker'i uzerinden ---"
chroot "$TREE" /system/bin/sh -c \
  ". $ENVF; export LD_LIBRARY_PATH; /system/bin/linker64 /tmp/libproof" 2>&1 | tail -40
rc1=${PIPESTATUS[0]}
echo ""
echo "--- (2) dogrudan (binfmt_misc) ---"
chroot "$TREE" /system/bin/sh -c \
  ". $ENVF; export LD_LIBRARY_PATH; /tmp/libproof" 2>&1 | tail -40
rc2=${PIPESTATUS[0]}
echo ""
if [ "$rc1" -eq 0 ] || [ "$rc2" -eq 0 ]; then
  ok "KUTUPHANE CAGIRISI BASARILI (linker=$rc1 dogrudan=$rc2)"
  exit 0
fi
warn "iki yol da basarisiz (rc=$rc1 / $rc2)"
exit 1