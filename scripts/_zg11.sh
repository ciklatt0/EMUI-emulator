#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) 25 sn: app_process64 yasiyor MU (exe ile tarama, 500 ms) ==="
A 'i=0; prev=X
while [ $i -lt 50 ]; do
  HIT=""
  for d in /proc/[0-9]*; do
    case "$(readlink $d/exe 2>/dev/null)" in
      *app_process64*) HIT="$HIT $(basename $d)" ;;
    esac
  done
  if [ "$HIT" != "$prev" ]; then
    if [ -z "$HIT" ]; then echo "  t=$((i/2))sn YOK"; else
      for p in $HIT; do echo "  t=$((i/2))sn pid=$p state=$(awk "{print \$3}" /proc/$p/stat 2>/dev/null) thr=$(ls /proc/$p/task 2>/dev/null | wc -l) libart=$(grep -c libart /proc/$p/maps 2>/dev/null)"; done
    fi
    prev="$HIT"
  fi
  i=$((i+1)); /bb/sleep 0.5
done'
echo ""
echo "=== 2) init.svc.zygote / arkinit ==="
A 'getprop init.svc.zygote; getprop init.svc.arkinit'
echo ""
echo "=== 3) arkinit loglari ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "arkinit" | grep -v "avc:" | tail -6; echo "(bos = sessiz)"'
echo ""
echo "=== 4) SELinux: zygote icin AVC var MI ==="
A 'logcat -d 2>/dev/null | grep "avc:" | grep -iE "zygote|app_process|denied" | tail -5; echo "--- toplam AVC: $(logcat -d 2>/dev/null | grep -c "avc:")"'