#!/bin/bash
# NOT EDILEN TUMADILIK: app_process64'un maps satiri sayisi
# zamanla AZALIYOR:
#   t=0.2s  maps=34
#   t=0.5s  maps=2264
#   t=1.0s  maps=1658
#   t=2.0s  maps=1072
#   t=3.0s  maps=1075
# 1132 kutuphaneden 536'si BIR SANIYE ICINDE UNMAP OLUYOR.
# Bu normal degil. Iki olcek var:
#   (a) gercekten dlclose/dlmopen bir sey cikariyor
#   (b) /proc/PID/maps okumasi kirpilmis (bellek baskisi)
# 100 ms aralikla 4 sn olcerek ayirt edecegiz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== init'in baslattigi gercek zygote, 4 sn 100 ms aralikla ==="
A 'P=""
i=0
while [ $i -lt 40 ]; do
  Q=$(getprop init.svc_debug_pid.zygote 2>/dev/null)
  if [ -n "$Q" ] && [ -d /proc/$Q ] && [ -n "$(readlink /proc/$Q/exe 2>/dev/null)" ]; then P=$Q; break; fi
  i=$((i+1)); /bb/sleep 0.1
done
if [ -z "$P" ]; then echo "  zygote yakalanamadi"; exit; fi
echo "  yakalandi pid=$P"
for i in $(seq 0 39); do
  [ -d /proc/$P ] || { echo "  t=${i} OLDI"; break; }
  N=$(grep -c . /proc/$P/maps 2>/dev/null)
  LA=$(grep -c "libart" /proc/$P/maps 2>/dev/null)
  printf "  t=%-5s maps=%-5s libart=%-3s\n" "$((i*100))ms" "$N" "$LA"
  /bb/sleep 0.1
done'