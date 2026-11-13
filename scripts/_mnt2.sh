#!/bin/bash
# /linkerconfig IKINCI KEZ mount edilmis; ikincisi birincisini
# gizliyor. Biz ikinciye yaziyoruz, eski namespace'li surecler
# birinciyi (bos) goruyor.
# Kim mount ediyor, ne zaman?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) mount sayisi ve mountinfo detayi ==="
A 'grep -c " /linkerconfig " /proc/mounts; echo "--- mountinfo:"; grep " /linkerconfig " /proc/mountinfo'
echo ""
echo "=== 2) 20 sn boyunca mount sayisi degisiyor mu ==="
A 'i=0; prev=""; while [ $i -lt 20 ]; do
  n=$(/bb/grep -c " /linkerconfig " /proc/mounts)
  if [ "$n" != "$prev" ]; then echo "[$i] mount sayisi=$n"; prev=$n; fi
  i=$((i+1)); /bb/sleep 1
done; echo "bitti (toplam=$prev)"'
echo ""
echo "=== 3) hw/init.rc'deki linkerconfig mount satiri ==="
A 'grep -n "linkerconfig" /system/etc/init/hw/init.rc | head -8'