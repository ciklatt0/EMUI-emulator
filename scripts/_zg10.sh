#!/bin/bash
# pidof zygote64 BOS cikiyor ama bu zygote'un yok oldugu
# anlamina gelmez: zygote argv'sini temizler, /proc/PID/cmdline
# BOS kalir. Dogru tanimlayici /proc/PID/exe -> app_process64
# olcusudur. 30 sn boyunca 100 ms'de bir tarayalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) 30 sn: app_process64 YASIYOR MU (exe ile tarama) ==="
A 'i=0; prev=""
while [ $i -lt 150 ]; do
  HIT=""
  for d in /proc/[0-9]*; do
    E=$(readlink $d/exe 2>/dev/null)
    case "$E" in
      *app_process64*) HIT="$HIT $(basename $d)" ;;
    esac
  done
  if [ "$HIT" != "$prev" ]; then
    for p in $HIT; do
      echo "  t=$((i/10))sn pid=$p state=$(awk "{print \$3}" /proc/$p/stat 2>/dev/null) thr=$(ls /proc/$p/task 2>/dev/null | wc -l) libart=$(grep -c libart /proc/$p/maps 2>/dev/null) maps=$(grep -c . /proc/$p/maps 2>/dev/null)"
    done
    [ -z "$HIT" ] && echo "  t=$((i/10))sn HIC YOK"
    prev="$HIT"
  fi
  i=$((i+1)); /bb/sleep 0.1
done'
echo ""
echo "=== 2) simdi ne calisiyor (TUM app_process yok, zygote hic dogmuyor mu) ==="
A 'for d in /proc/[0-9]*; do E=$(readlink $d/exe 2>/dev/null); case "$E" in *app_process*) echo "$(basename $d) -> $E";; esac; done; echo "(bos = zygote hic yasamiyor)"'
echo ""
echo "=== 3) init.svc.zygote + arkinit durumu ==="
A 'getprop init.svc.zygote; getprop init.svc.arkinit; getprop init.svc_debug_pid.arkinit'
echo ""
echo "=== 4) onrestart zinciri: zygote olunce arkinit'e ne oluyor ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "arkinit|mygote" | grep -v "avc:" | tail -8; echo "(bos ise arkinit sessiz)"'