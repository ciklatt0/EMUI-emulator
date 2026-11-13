#!/usr/bin/env bash
# Tum hatti sirayla calistirir:
#   10 kernel -> 20 busybox -> 30 initramfs -> 40 test boot
set -uo pipefail
S="$(dirname "$(readlink -f "$0")")"
sed -i '1s/^\xEF\xBB\xBF//' "$0" 2>/dev/null || true

fail=0
for step in 10-fetch-kernel 20-build-busybox 30-make-initramfs; do
  echo ""
  echo "##################################################"
  echo "# $step"
  echo "##################################################"
  if ! bash "$S/$step.sh"; then
    echo "[DURDU] $step basarisiz"
    fail=1
    break
  fi
done

if [[ $fail -eq 0 ]]; then
  echo ""
  echo "##################################################"
  echo "# 40-boot (test)"
  echo "##################################################"
  bash "$S/40-boot.sh" --test
fi