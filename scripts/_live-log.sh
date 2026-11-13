#!/bin/bash
set -u
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F ($(wc -l < "$F") satir)"
echo ""
echo "--- HARMONYOS BOOT / /data / panic / bb-null ---"
grep -n 'HARMONYOS BOOT\|/data:\|Kernel panic\|Read-only file system' "$F" | head -6
echo ""
printf 'vold satir        : %s\n' "$(grep -c 'vold' "$F")"
printf 'starting service  : %s\n' "$(grep -c 'starting service' "$F")"
printf 'CANNOT LINK       : %s\n' "$(grep -c 'CANNOT LINK' "$F")"
echo ""
echo "--- init_user0 / son servisler ---"
grep -n 'init_user0\|Failure (reboot' "$F" | head -5
grep 'starting service' "$F" | tail -5