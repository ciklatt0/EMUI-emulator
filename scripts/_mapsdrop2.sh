#!/bin/bash
# Onceki deneme zygote'yi exec ANINDA yakaladi (maps=0).
# Bu kez PID degistiginde takibi BASLATIP ayni sureci izleyelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== ayni zygote surecini 5 sn, 100 ms aralikla izle ==="
A 'TRACK=""
for i in $(seq 0 120); do
  P=$(getprop init.svc_debug_pid.zygote 2>/dev/null)
  if [ -n "$P" ] && [ -d /proc/$P ] && [ -n "$(readlink /proc/$P/exe 2>/dev/null)" ]; then
    if [ "$P" != "$TRACK" ]; then
      N=$(grep -c . /proc/$P/maps 2>/dev/null)
      if [ "${N:-0}" -gt 300 ]; then TRACK=$P; echo "  --- takip basliyor pid=$P"; fi
    else
      N=$(grep -c . /proc/$P/maps 2>/dev/null)
      LA=$(grep -c "libart" /proc/$P/maps 2>/dev/null)
      NB=$(grep -c "\.so" /proc/$P/maps 2>/dev/null)
      printf "  t=%-4s maps=%-5s so=%-4s libart=%-3s\n" "${i}" "$N" "$NB" "$LA"
    fi
  fi
  /bb/sleep 0.1
done'