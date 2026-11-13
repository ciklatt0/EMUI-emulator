#!/bin/bash
# Yamayi URETILMIS /init icinde dogrula (calistirmadan once).
# Iki sey kontrol ediliyor:
#  1) /bb/sed gercekten var mi (initramfs'te busybox eklentisi)
#  2) /init, ro.adb.secure icin /bb/sed -i kullanıyor mu
set -u
R=/root/harmony-build/initramfs-boot

echo "=== 1) busybox eklentileri (sed var mi) ==="
ls -l "$R/bb/sed" 2>/dev/null || echo "  /bb/sed YOK !"
ls "$R/bb/" 2>/dev/null | tr '\n' ' '
echo ""
echo ""
echo "=== 2) /init icindeki ro.adb.secure blogu ==="
grep -n 'ro\.adb\.secure\|ro\.secure\|ro\.debuggable\|HARMONY-EMU' "$R/init" | head -20
echo ""
echo "=== 3) /init icinde BARE sed (PATH'e bagli, riskli) ==="
grep -n '^\s*sed ' "$R/init" | head -5 || echo "  yok"
echo ""
echo "=== 4) busybox sed -i destekli mi (yerelde test) ==="
cd /root/harmony-build
printf 'ro.adb.secure=1\nro.secure=1\nkeep=1\n' > /tmp/_t.prop
./busybox-1.36.1/busybox sed -i 's/^ro\.adb\.secure=.*/#& # YORUM/' /tmp/_t.prop 2>&1 | head -2
echo "  sonuc:"; cat /tmp/_t.prop | sed 's/^/    /'
rm -f /tmp/_t.prop