#!/bin/bash
# arkprobe YASIYOR (pid 8355) ama seri logda dltrace ciktisi YOK.
# LD_PRELOAD uygulanmis mi? Iki yerden dogruluyoruz:
#   /proc/PID/environ  -> LD_PRELOAD degiskeni
#   /proc/PID/maps     -> dltrace.so haritada mi
# DIKKAT: Android'in linker'i LD_PRELOAD'u bazi durumlarda yok
# sayabilir; o zaman constructor da calismaz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) arkprobe ORTAM (LD_PRELOAD var MI) ==="
A 'P=$(getprop init.svc_debug_pid.arkprobe)
   echo "  pid=$P state=$(awk "{print \$3}" /proc/$P/stat) maps=$(grep -c . /proc/$P/maps 2>/dev/null)"
   tr "\0" "\n" < /proc/$P/environ 2>/dev/null | grep -E "LD_PRELOAD|ARK_|ANDROID" | sed "s/^/    /"'
echo ""
echo "=== 2) dltrace.so HARITADA MI (constructor calisti mi) ==="
A 'P=$(getprop init.svc_debug_pid.arkprobe)
   echo "  dltrace.so haritada: $(grep -c dltrace /proc/$P/maps 2>/dev/null)"
   grep -oE "/data/dltrace\.so" /proc/$P/maps 2>/dev/null | head -2 | sed "s/^/    /"'
echo ""
echo "=== 3) logcat: bu PIDye ait satirlar ==="
A 'P=$(getprop init.svc_debug_pid.arkprobe)
   logcat -d -b all -v time 2>/dev/null | grep "( *$P)" | grep -v "avc:" | tail -15
   echo "  --- toplam: $(logcat -d -b all 2>/dev/null | grep -c "( *$P)")"'
echo ""
echo "=== 4) logcat: arkprobe/ark ile ilgili TUMU ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "arkprobe|panda|ark" | grep -v "avc:" | tail -12'
echo ""
echo "=== 5) suresi nasil bitti (seri log) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -a "arkprobe" "$F" | tail -6 | sed 's/\[[^]]*\] //' | cut -c1-120