#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== 1) adbd dahili dizeleri (auth.cpp/main.cpp/listening) ==="
grep -aE "auth\.cpp|main\.cpp|watchdog\.cpp|mdns\.cpp|listening on|adbd started|Cannot bind" "$F" | tail -10 | sed 's/\[[^]]*\] //' | cut -c1-200
echo ""
echo "=== 2) tum logda 'Service .adbd' cevresi ==="
grep -a -B 2 "Service 'adbd'" "$F" | tail -14 | sed 's/\[[^]]*\] //' | cut -c1-180
echo ""
echo "=== 3) /bb/nb ve /tmp var mi ==="
grep -aE "bb/nb|ld.stock" "$F" | tail -4 | sed 's/\[[^]]*\] //' | cut -c1-140
echo ""
echo "=== 4) rc'deki adbd tanimi (paketlenmis hali) ==="
grep -a -A 10 "adbd: APEX init.rc" "$F" | head -14 | sed 's/\[[^]]*\] //' | cut -c1-140