#!/bin/bash
# /init /devblk/vda29'u ext4 olarak /data'ya baglamaya CALISIYOR
# ama konukta /data bir TMPFS. Nedenini olcelim.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) /init'in /data mesajlari ==="
grep -aE "/data:|DATADEV|vda29" "$F" | head -12 | sed 's/\[[^]]*\] //' | cut -c1-130
echo ""
echo "=== 2) denetleyici /data uzerine bir sey bagliyor mu ==="
grep -aE "tmpfs.*data|data.*tmpfs|mount.*data" "$F" | head -8 | sed 's/\[[^]]*\] //' | cut -c1-130