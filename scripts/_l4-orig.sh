#!/bin/bash
# Konukta /system/etc/init/init.rc YOK ama 166 servis tanimli.
# Soru: ORIJINAL firmware partition'inda master init.rc var mi?
# Cevap /bb/rclog'un kopyaladigi kaynakta ve partition'da.
set -u
OVL=/tmp/ovlsrc
echo "=== 1) partition'da /etc/init listesi (ilk 30 + init.rc arama) ==="
# system partition system=1048576 byte ofset (PLAN.md'e gore)
python3 "$(dirname "$0")/dump.erofs" \
  --img=/root/harmony-build/boot/system-disk.img --offset=1048576 \
  --ls=/etc/init 2>&1 | head -8
echo "  (cikti yoksa dump.erofs yolu/argumanlari kontrol edilmeli)"
echo ""
echo "=== 2) daha once uretilen overlay-src var mi ==="
ls -d /tmp/ovlsrc /tmp/overlay-src 2>/dev/null
find /tmp -maxdepth 3 -name 'init.rc' -path '*etc/init*' 2>/dev/null | head -5
echo ""
echo "=== 3) 81-boot-zygote.sh hangi dizinleri kopyaliyor (RCROOTS) ==="
grep -n 'ROOTS\|RCROOTS\|for d in ' "$(dirname "$0")/81-boot-zygote.sh" | head -15
echo ""
echo "=== 4) init.environ.rc icerigi (bizim urettigimiz) ==="
grep -n "init.environ.rc" "$(dirname "$0")/81-boot-zygote.sh" | head -5