#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) denetleyici KAYBOLMUŞ mesaji var mi ==="
grep -a "KAYBOLMUS" "$F" | tail -5 | sed 's/\[[^]]*\] //' | cut -c1-110
echo "  (bos = config hic kaybolmadi)"
echo ""
echo "=== 2) canli config durumu ==="
A 'ls -l /linkerconfig/ld.config.txt /linkerconfig/bootstrap/ld.config.txt /bb/nb/ld.stock 2>&1'
echo ""
echo "=== 3) linkeri VARSAYILAN'a dusuren anlar (ilk 3) ==="
A 'logcat -d 2>/dev/null | grep -n "failed to find generated linker" | head -3'
echo ""
echo "=== 4) o andan hemen once ne olmus (CANNOT LINK ilk satirlari) ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | head -3'
echo ""
echo "=== 5) linker config gercekten yazili mi (sembol) ==="
A 'head -1 /linkerconfig/ld.config.txt 2>&1'
echo ""
echo "=== 6) 15 sn gozlem ==="
A 'i=0; prev=V; ch=0; while [ $i -lt 30 ]; do
  if [ -f /linkerconfig/ld.config.txt ]; then c=V; else c=YOK; fi
  [ "$c" != "$prev" ] && echo "[$i] $prev -> $c" && prev=$c && ch=1
  i=$((i+1)); sleep 0.5
done; [ $ch -eq 0 ] && echo "15 sn boyunca degismedi"'