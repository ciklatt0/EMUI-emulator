#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) ld.config sonucu (search vs izinli) ==="
grep -aE "ld.config.txt yamalan|permitted\(\$|IZINSIZ|APEX yolu" "$F" | tail -4 | sed 's/\[[^]]*\] //'
echo ""
echo "=== 2) kalan CANNOT LINK hatalari ==="
A 'logcat -d 2>/dev/null | grep -c "CANNOT LINK"'
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | tail -6'
echo ""
echo "=== 3) zygote/system_server durumu ==="
A 'logcat -d 2>/dev/null | grep -iE "ZygoteInit|SystemServer|system_server" | tail -8'
echo ""
echo "=== 4) init: critical process zygote ==="
grep -a "critical process" "$F" | tail -3 | cut -c1-140
echo ""
echo "=== 5) zygote PID durumu ==="
A 'for p in $(pgrep zygote64 2>/dev/null); do echo "pid=$p state=$(cut -d" " -f3 /proc/$p/stat) threads=$(ls /proc/$p/task | wc -l)"; done'