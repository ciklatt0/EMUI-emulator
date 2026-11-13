#!/bin/bash
# ld.config.txt duzeltmesi dogrulandi mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) ld.config yamalama logu ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -E "ld.config.txt yamalan|cozulen|import somutlastirilamadi" "$F" 2>/dev/null | head -5

echo ""
echo "=== 1) [system] bolumunde APEX yolu sayisi (OLCUM ARACI) ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /apex\//{n++} END{print \"[system] icinde apex yolu: \" n+0}' /linkerconfig/ld.config.txt"

echo ""
echo "=== 2) dosyanin ILK 6 satiri (artik isaret + [system] olmali) ==="
A 'head -6 /linkerconfig/ld.config.txt'

echo ""
echo "=== 3) app_process64 linker testi ==="
A '/system/bin/app_process64 --help 2>&1 | head -4'

echo ""
echo "=== 4) zygote durumu ==="
A 'getprop init.svc.zygote; getprop sys.boot_completed; getprop init.svc.surfaceflinger'