#!/bin/bash
# zygote simdi canli mi, crash-loop mu? ve neden?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== zygote svc + surec sayisi (5 sn arayla 3 kez) ==="
for i in 1 2 3; do
  A 'echo "svc=$(getprop init.svc.zygote) app_process=$(ps -A 2>/dev/null | grep -c app_process) canli=$(ps -A 2>/dev/null | grep app_process | grep -vc "\[")"'
  sleep 5
done
echo ""
echo "=== son zygote hatasi ==="
A 'logcat -d 2>/dev/null | grep -iE "zygote|dalvik-cache|Error creating|Fatal signal" | tail -8'
echo ""
echo "=== init'in zygote ile ilgili son mesajlari ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -E "zygote" "$F" | tail -8 | sed 's/\[[^]]*\] //' | cut -c1-140