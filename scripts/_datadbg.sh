#!/bin/bash
# /data duzeltmesi calismadi. Denetleyici gunlugundeki mesajimizi
# ve mount denemesinin sonucunu olcelim.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) yeni mesajimiz gorundu mu ==="
grep -a 'GERCEK BOLUM' "$F" | tail -3 | sed 's/\[[^]]*\] //' | cut -c1-130
echo "  (bos = mount denemesi hic denenmedi ya da basarisiz oldu)"
echo ""
echo "=== 2) ensure_data_dirs bolumu calisti mi ==="
grep -a 'zaten mountlu\|tmpfs baglandi\|--- /data ---' "$F" | tail -5 | sed 's/\[[^]]*\] //' | cut -c1-130
echo ""
echo "=== 3) /devblk/vda29 su an ==="
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
A 'ls -l /devblk/vda29 2>&1
   [ -b /devblk/vda29 ] && echo "  BLOK CIHAZ" || echo "  blok cihaz DEGIL"
   echo "--- elle dene:"
   mount -t ext4 -o rw /devblk/vda29 /data 2>&1 && echo "  MOUNT BASARILI" || echo "  MOUNT BASARISIZ"
   mount | grep " /data "'