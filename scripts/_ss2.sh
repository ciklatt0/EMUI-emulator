#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)

echo "=== 1) tracefs + ld.config dagitimi (log) ==="
grep -aE "tracefs|apex/etc dizinine|yamalandi: search" "$F" | tail -5 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 2) zygote + system_server ==="
A 'getprop init.svc.zygote; ps -A 2>/dev/null | grep -iE "zygote|system_server" | head -6'
echo ""
echo "=== 3) system_server ilerlemesi (boot_progress) ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "boot_progress|SystemServer|PackageManager|ActivityManager.*Start proc" | tail -15'
echo ""
echo "=== 4) dlopen / CANNOT LINK sayaci ==="
A 'logcat -d 2>/dev/null | grep -c "CANNOT LINK"'
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | tail -4'
echo ""
echo "=== 5) crash_dump64 config uyarisi gitti mi ==="
A 'logcat -d 2>/dev/null | grep -c "couldn.t read config file"'