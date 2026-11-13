#!/bin/bash
# ELLE BASLATILAN zygote ile INIT'in BASLATTIIGI zygote FARKLI:
#   elle  -> hic "START ZygoteInit" basmiyor
#   init  -> basiyor, ama 1-5 sn sonra oluyor
# Olcumu INIT'IN baslattigi gercek zygote uzerinde yapalim.
# PID kaynagi: init.svc_debug_pid.zygote
# AYRICA /proc/PID/environ ile GERCEK ortam degiskenlerini okuyaliz
# (bizim setenv yamalarimiz gercekten uygulaniyor mu?).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) 40 sn boyunca gercek zygote PID'sini YAKALA + /proc oku ==="
A 'i=0; last=""
while [ $i -lt 40 ]; do
  P=$(getprop init.svc_debug_pid.zygote 2>/dev/null)
  if [ -n "$P" ] && [ "$P" != "$P_invalid" ] && [ -d /proc/$P ] && [ "$P" != "$last" ]; then
    last=$P
    echo "  YAKALANDI pid=$P t=${i}s state=$(awk "{print \$3}" /proc/$P/stat 2>/dev/null) thr=$(ls /proc/$P/task 2>/dev/null | wc -l)"
    echo "    exe  = $(readlink /proc/$P/exe 2>/dev/null)"
    echo "    libart=$(grep -c libart.so /proc/$P/maps)  libartbase=$(grep -c libartbase /proc/$P/maps)  maps=$(grep -c . /proc/$P/maps)"
    echo "    --- GERCEK ORTAM:"
    tr "\0" "\n" < /proc/$P/environ 2>/dev/null | grep -E "ANDROID|LD_" | sed "s/^/      /"
  fi
  i=$((i+1)); /bb/sleep 1
done
echo "  (son yakalama: $last)"'
echo ""
echo "=== 2) init.svc.zygote + init.svc_debug_pid.arkinit ==="
A 'getprop init.svc.zygote; echo "---"; getprop init.svc_debug_pid.arkinit'