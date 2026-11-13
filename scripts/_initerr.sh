#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /r/system/bin/init tam hata mesaji ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK EXECUTABLE \"/r/system/bin/init\"" | head -3'
echo ""
echo "=== 2) bu ikili gercekten ne: /r/system/bin/init ==="
A 'ls -l /r/system/bin/init; /system/bin/toybox file /r/system/bin/init 2>&1 | head -2'
echo ""
echo "=== 3) [vendor] bolumu CANLI (sistem yolu eklenmis mi) ==="
A "awk '/^\[vendor\]/{s=1;next} /^\[/{s=0} s && /search\.paths/' /linkerconfig/ld.config.txt | tr ':' '\n' | grep -E 'system|vendor' | head -6"
echo ""
echo "=== 4) init bir vendor alt baglami mi (kim baslatiyor) ==="
A 'logcat -d 2>/dev/null | grep -iE "subcontext|Restarting" | tail -4'
echo ""
echo "=== 5) zygote durumu ==="
A 'getprop init.svc.zygote; for p in $(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f1); do echo "pid=$p state=$(cut -d" " -f3 /proc/$p/stat)"; done | head -4'