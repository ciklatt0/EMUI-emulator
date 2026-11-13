#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== 1) ld.config yama/kaybolma gunlugu ==="
grep -aE "ld.config.txt yamalan|KAYBOLMUS|apex/etc dizinine|SIFIRLADI|ld.config.txt: " "$F" | tail -10 | sed 's/\[[^]]*\] //' | cut -c1-130
echo ""
echo "=== 2) /linkerconfig mount sayisi ==="
grep -a "nabiz" "$F" | tail -1 | cut -c1-100
echo ""
echo "=== 3) CANNOT LINK zaman araligi (ilk 5 zaman damgasi) ==="
grep -a "CANNOT LINK" "$F" | head -5 | sed 's/^\[ *//;s/\].*CANNOT LINK EXECUTABLE "/ /;s/".*//' | cut -c1-60