#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) init baslattigi TUM servisler (tekil) ==="
grep -ao "starting service '[a-zA-Z0-9_.-]*'" "$F" | sort -u | head -40
echo ""
echo "=== 2) toplam kac kez starting service ==="
grep -ac "starting service" "$F"
echo ""
echo "=== 3) class core servisleri (bizim tanimimiza gore) ==="
grep -a "critical-\|critical?\|critical-  :" "$F" | tail -3 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 4) class_start / Trigger mesajlari ==="
grep -aiE "class_start|trigger|action.*core" "$F" | grep -av avc | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-170
echo ""
echo "=== 5) 'Cannot start an updatable service' mesajlari ==="
grep -a "updatable service" "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-190