#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libnativeloader.so diskte ==="
A 'find /system /apex -name "libnativeloader.so" 2>/dev/null | head -3'
echo ""
echo "=== 2) config [system] search.paths: art var MI ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /search\.paths/' /linkerconfig/ld.config.txt | grep -n 'art' | head -4"
echo ""
echo "=== 3) config'in NE ZAMAN yazildi (lisansaat) ==="
A 'ls -l --time-style=+%H:%M:%S /linkerconfig/ld.config.txt /bb/nb/ld.stock 2>&1'
echo ""
echo "=== 4) /apex/com.android.art/lib64 MEVCUT MU ==="
A 'ls -d /apex/com.android.art/lib64 2>&1; ls /apex/ | head -8'
echo ""
echo "=== 5) denetleyici logu: yama ne zaman/kac kez ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -aE "ld.config.txt yamalan|KAYBOLMUS|apex/etc dizinine" "$F" | tail -5 | sed 's/\[[^]]*\] //' | cut -c1-120