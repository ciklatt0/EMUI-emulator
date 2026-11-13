#!/bin/bash
# APEX icindeki /etc/init.rc'yi TAM olarak goster; bizim init.environ.rc
# tanimimizla satir satir karsilastir. Firmware'in kendi tanimi calisiyor
# mu, yoksa bizim ekledigimiz bir sey mi bozuyor?
set -u
rm -rf /tmp/adbdx; mkdir -p /tmp/adbdx
cd /tmp/adbdx || exit 1
unzip -o -q /root/harmony-build/apexfiles/com.android.adbd.apex
mount -o loop,ro /tmp/adbdx/apex_payload.img /tmp/adbdx 2>/dev/null

echo "=== APEX /etc/init.rc (birebir) ==="
cat -A /tmp/adbdx/etc/init.rc 2>/dev/null | sed 's/\$$//' | head -20
echo ""
echo "=== bizim init.environ.rc adbd tanimi ==="
awk '/^service adbd/{f=1} f{print} /^    stderr/{exit}' /root/harmony-build/initramfs-boot/init.environ.rc
echo ""
echo "=== fark: firmware'de 'class core' + 'disabled' var; biz 'disabled' cikardi mi? ==="
grep -c 'disabled' /tmp/adbdx/etc/init.rc 2>/dev/null