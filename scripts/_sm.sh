#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== 1) servicemanager izleri ==="
grep -a "servicemanager" "$F" | grep -av "avc:" | tail -8 | sed 's/\[[^]]*\] //' | cut -c1-170
echo ""
echo "=== 2) init: servicemanager gecen satirlar ==="
grep -a "Service 'servicemanager'\|starting service 'servicemanager'\|service 'hwservicemanager'" "$F" | tail -8 | sed 's/\[[^]]*\] //' | cut -c1-170
echo ""
echo "=== 3) CANNOT LINK / linker uyarisi (kernel log) ==="
grep -aE "CANNOT LINK|undefined namespace|using default configuration" "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-190
echo ""
echo "=== 4) config kontrol logu ==="
grep -aE "config anahtar kontrolu|yamalandi: search|gecersiz anahtar" "$F" | tail -4 | sed 's/\[[^]]*\] //' | cut -c1-150
echo ""
echo "=== 5) olum anindaki komsu mesajlar ==="
grep -a -A 4 "Service 'servicemanager'" "$F" | tail -12 | sed 's/\[[^]]*\] //' | cut -c1-170