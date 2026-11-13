#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) config + yedek durumu ==="
A 'ls -l /linkerconfig/ld.config.txt /bb/nb/ld.stock 2>&1'
A 'grep -c apex /linkerconfig/ld.config.txt 2>&1'
echo ""
echo "=== 2) bolumler ==="
A 'grep -n "^\[" /linkerconfig/ld.config.txt 2>&1'
echo ""
echo "=== 3) [system] arama yollari var MI ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /search\.paths/' /linkerconfig/ld.config.txt 2>&1 | head -3"
echo ""
echo "=== 4) /linkerconfig mount ==="
A 'mount | grep linkerconfig'
echo ""
echo "=== 5) bootstrap/default dizinleri ==="
A 'ls -l /linkerconfig/ 2>&1 | head -6'
echo ""
echo "=== 6) kanit: config ne zaman kayboluyor (10 sn) ==="
A 'i=0; prev=V; while [ $i -lt 20 ]; do
  if [ -f /linkerconfig/ld.config.txt ]; then c=V; else c=YOK; fi
  [ "$c" != "$prev" ] && echo "[$i] $prev -> $c" && prev=$c
  i=$((i+1)); sleep 0.5
done; echo "bitti"'