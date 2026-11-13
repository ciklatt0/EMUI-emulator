#!/bin/bash
# Zygote ~5 sn'de bir yeniden doguyor. Kim olduruyor?
# Iki aday: init (servis cikti) veya BIZIM denetleyicimiz
# (ensure_zygote: canlilik olcup "bayat running" gorunce
#  ctl.stop + ctl.start yapiyor). Seri logu okuyalim.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) denetleyicinin zygote ile ilgili kararlari ==="
grep -aE "zygote" "$F" | grep -aviE "CANNOT LINK|START com.android|appproc|boot_progress" | tail -20 | sed 's/\[[^]]*\] //' | cut -c1-150
echo ""
echo "=== 2) init ctl.stop / ctl.start izleri (ham init ciktisi) ==="
grep -aE "ctl\.(stop|start)|Sending signal .* to service" "$F" | tail -15 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 3) ensure_zygote fonksiyonunun kaynak kodu ==="
grep -n "ensure_zygote" "$(dirname "$0")/81-boot-zygote.sh" | head -5