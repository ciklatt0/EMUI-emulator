#!/bin/bash
# arkprobe calisti (init.svc.arkprobe=running). stdio_to_kmsg
# sayesinde dltrace ciktisi SERI LOGDA. Yeni satirlari okuyalim.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F ($(wc -l < "$F") satir)"
echo ""
echo "=== 1) dltrace izleri (TAM) ==="
grep -a "dltrace" "$F" | tail -50 | sed 's/\[[^]]*\] //' | cut -c1-130
echo ""
echo "=== 2) ark ile ilgili satirlar ==="
grep -aiE "ark|panda" "$F" | grep -av "avc:" | tail -20 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 3) CANNOT LINK / hatalar ==="
grep -a "CANNOT LINK\|not found" "$F" | tail -10 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 4) arkprobe servisi durumu ==="
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
A 'echo "  init.svc.arkprobe = [$(getprop init.svc.arkprobe)]"
   P=$(getprop init.svc_debug_pid.arkprobe); echo "  pid=$P"
   if [ -n "$P" ] && [ -d /proc/$P ]; then
     echo "  state=$(awk "{print \$3}" /proc/$P/stat) thr=$(ls /proc/$P/task 2>/dev/null | wc -l) maps=$(grep -c . /proc/$P/maps 2>/dev/null)"
     echo "  libark=$(grep -c libark /proc/$P/maps 2>/dev/null) libart=$(grep -c libart /proc/$P/maps 2>/dev/null)"
     echo "  --- ark kutuphaneleri:"
     grep -oE "/[a-zA-Z0-9./_]*ark[a-zA-Z0-9._]*\.so" /proc/$P/maps 2>/dev/null | sort -u | head -10
   fi'