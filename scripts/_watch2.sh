#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 60 sn gozlem: config ne zaman kayboluyor ==="
A 'i=0; prev=V; while [ $i -lt 30 ]; do
  if [ -f /linkerconfig/ld.config.txt ]; then cur=V; else cur=YOK; fi
  if [ "$cur" != "$prev" ]; then
    echo "[$i] $prev -> $cur  mount=$(mount | grep linkerconfig | head -1)"
    prev=$cur
  fi
  i=$((i+1)); sleep 2
done; echo "[son] $(mount | grep linkerconfig | head -1)"'