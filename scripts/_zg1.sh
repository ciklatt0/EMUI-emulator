#!/bin/bash
# zygote artik BAGLANIYOR (CANNOT LINK=0) ama system_server fork
# edilmiyor ve zygote 3 sn sonra RC=0 ile cikiyor.
# Once "init.svc.zygote=running"in BAYAT olmadigini dogrula, sonra
# zygote'nin gercekten yasayip yasamadigini olc.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote SURECI gercekten yasiyor mu (bayat running olabilir) ==="
A 'P=$(/bb/pidof zygote64 2>/dev/null); echo "pidof zygote64 = [$P]"
i=0
while [ $i -lt 12 ]; do
  P=$(/bb/pidof zygote64 2>/dev/null)
  if [ -n "$P" ]; then
    for p in $P; do echo "  t=$i pid=$p state=$(cut -d" " -f3 /proc/$p/stat 2>/dev/null) thr=$(ls /proc/$p/task 2>/dev/null | wc -l)"
    done
  else
    echo "  t=$i yok"
  fi
  i=$((i+1)); /bb/sleep 2
done'