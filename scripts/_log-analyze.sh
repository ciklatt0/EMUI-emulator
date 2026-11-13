#!/bin/bash
set -u
L="$(dirname "$0")/../logs/boot-zygote.log"
echo "satir: $(wc -l < "$L")"
printf 'Subcontext exited : %s\n' "$(grep -c 'Subcontext exited' "$L")"
printf 'starting service  : %s\n' "$(grep -c 'starting service' "$L")"
printf 'CANNOT LINK       : %s\n' "$(grep -c 'CANNOT LINK' "$L")"
printf 'permissive=0      : %s\n' "$(grep -c 'permissive=0' "$L")"
printf 'perform_apex_conf : %s\n' "$(grep -c 'perform_apex_config' "$L")"
printf 'adbd AYAKTA       : %s\n' "$(grep -c 'adbd AYAKTA' "$L")"
echo ""
echo "=== BASLATILAN SERVISLER (turler) ==="
grep 'starting service' "$L" | sed 's/.*starting service //' | sort | uniq -c | sort -rn | head -20
echo ""
echo "=== post-fs-data / apexd durumu ==="
grep -nE 'post-fs-data|perform_apex|apexd.status|class_restart|Sending service' "$L" | head -15
echo ""
echo "=== zygote / system_server izleri ==="
grep -nE 'zygote|app_process|SystemServer|boot_completed|init_user0' "$L" | head -15
echo ""
echo "=== son 12 satir ==="
tail -12 "$L"