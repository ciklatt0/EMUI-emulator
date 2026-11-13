#!/bin/bash
set -u
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo "iter satiri sayisi: $(grep -c 'iter=' "$F")"
echo ""
echo "--- ilk 5 iter ---"
grep 'iter=' "$F" | head -5
echo "--- son 15 iter ---"
grep 'iter=' "$F" | tail -15
echo ""
echo "--- benzersiz iter degerleri (siklikla) ---"
grep -o 'iter=[0-9]*' "$F" | sort | uniq -c | tail -12
echo ""
echo "--- 'supervise' surec sayisi (avc kayitlarindan) ---"
grep -o 'pid=[0-9]* comm="supervise"' "$F" | sort -u | head