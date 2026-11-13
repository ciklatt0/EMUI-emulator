#!/bin/bash
# ZYIGOTE ASIL ENGELI: app_process64 libart.so'yu dlopen ile
# yukluyor ve HIC yuklemiyor. "Bagimlilik bulunamadi" mi
# "hic denenmedi mi" ayrimini YAZILIMLA kesinlestirelim.
#
# Plan: WSL'de aarch64-linux-gnu-gcc ile kucuk bir program derleyip
# konuga tasimak. Sorun: konuk bionic kullanir, WSL'de glibc var.
# Cozum: firmware'in kendi bionic'ini disk imajindan cikarip
# -nostdlib ile ona baglanmak (yaygin NDK'siz yontem).
set -e
IMG=/root/harmony-build/boot/system-disk.img
WORK=/root/harmony-build/dlprobe
echo "=== 1) disk imaji ve bionic konumu ==="
ls -l "$IMG" 2>&1 | head -1
ls -d "$WORK" 2>/dev/null || mkdir -p "$WORK"
echo ""
echo "=== 2) bionic'i imajdan cikarmaya calis ==="
# system bolumu (29 bolum) icinde /apex/com.android.runtime/lib64/bionic
if [ ! -f "$WORK/libc.so" ]; then
  # Once bolumun bir offset'ini bulalim
  echo "  bolum tablosu okunuyor..."
  fdisk -l "$IMG" 2>/dev/null | head -8 || echo "  fdisk yok"
fi
echo ""
echo "=== 3) daha kolay yol: bionic zaten WSL'de var mi ==="
ls /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 2>&1 | head -1
echo "  --- aarch64 gcc:"
which aarch64-linux-gnu-gcc
echo "  --- aarch64 statik deneme (glibc static, kernel'de calisir mi):"
cd "$WORK"
cat > t.c <<'EOF'
#include <unistd.h>
int main(void){ write(1,"HELLO-FROM-STATIC-ELF\n",23); return 0; }
EOF
aarch64-linux-gnu-gcc -static -O2 -o t t.c 2>&1 | head -3
ls -l t 2>&1 | head -1
file t 2>/dev/null | head -1 || true