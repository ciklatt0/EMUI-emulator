#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== 1) Subcontext exited OLUMUNDAN ONCEKI SATIRLAR ==="
grep -a -B 8 "Subcontext exited" "$F" | grep -av "avc:" | tail -14 | sed 's/\[[^]]*\] //' | cut -c1-200
echo ""
echo "=== 2) vendor rc yamalama durumu (VENDORRC) ==="
grep -aE "VENDORRC|vendor rc|Subcontext|init: Parsing file" "$F" | head -10 | sed 's/\[[^]]*\] //' | cut -c1-180
echo ""
echo "=== 3) Parsing file / vendor satirlari ==="
grep -a "Parsing file" "$F" | head -10 | sed 's/\[[^]]*\] //' | cut -c1-160
echo ""
echo "=== 4) Invalid keyword / parse hatalari ==="
grep -aE "Invalid keyword|Couldn't parse|error parsing" "$F" | head -8 | sed 's/\[[^]]*\] //' | cut -c1-190