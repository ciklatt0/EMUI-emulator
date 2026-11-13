#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote gercekten yasamis (state) ==="
A 'for p in $(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f1); do echo "pid=$p state=$(cut -d" " -f3 /proc/$p/stat) ppid=$(cut -d" " -f4 /proc/$p/stat) threads=$(ls /proc/$p/task | wc -l)"; done'
echo ""
echo "=== 2) zygote logcat (son 20) ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "zygote|ZygoteInit|appproc|system_server|SystemServer|preload|boot_progress" | tail -18'
echo ""
echo "=== 3) service zygote tanimi (canli) ==="
A 'grep -A 6 "^service zygote " /system/etc/init/hw/init.zygote64_32.rc | head -8'
echo ""
echo "=== 4) system_server'in ihtiyac duydugu /data yollari ==="
A 'ls -d /data/system/packages.xml /data/system/packages.list /data/system/framework 2>&1 | head -4'
echo ""
echo "=== 5) preload/dex suruculeri ==="
A 'ls /system/bin/dex2oat /system/bin/dexopt 2>&1 | head -3'