#!/bin/bash
# AOSP init hangi rc dosyalarini parse etti? Master init.rc yoksa
# init nereden servis tanimlari aliyor?
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== init'in rc/import mesajlari ==="
grep -iE "init: .*(import|parse|Couldn.t open|parsing|beginning file)" "$F" | head -20
echo ""
echo "=== logdaki tum 'zygote' gecen satirlar ==="
grep -in "zygote" "$F" | head -20
echo ""
echo "=== 'Failed to set property' / 'Unknown' hatalari ==="
grep -iE "Failed to set property|unknown (service|command|target)" "$F" | head -10
echo ""
echo "=== class_start / starting service ==="
grep -cE "starting service" "$F"
grep -E "starting service" "$F" | head -8