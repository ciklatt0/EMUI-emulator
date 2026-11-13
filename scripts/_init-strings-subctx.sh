#!/bin/bash
# init ikilisindeki 'subcontext' ile ilgili TUM dizeleri baglamla yazar.
set -u
F=$(ls -t /tmp/init.str 2>/dev/null | head -1)
if [ ! -f "$F" ]; then
  D=/root/harmony-build/boot/system-disk.img
  dump.erofs --offset=1048576 --cat --nid=25640233 /root/harmony-build/boot/system-disk.img > /tmp/init.bin 2>/dev/null
  strings -a /tmp/init.bin > /tmp/init.str
  F=/tmp/init.str
fi
echo "kaynak: $F ($(wc -l < "$F") satir)"
echo ""
echo "=== subcontext / Subcontext gecen satirlar ==="
grep -n -i 'subcontext' "$F"
echo ""
echo "=== bu dizelerin etrafindaki baglam (subcontext.cpp isaretinin oldugu yer) ==="
L=$(grep -n 'system/core/init/subcontext.cpp' "$F" | head -1 | cut -d: -f1)
sed -n "$((L-40)),$((L+10))p" "$F"