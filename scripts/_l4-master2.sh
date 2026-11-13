#!/bin/bash
# DIKKAT: getprop ciktisi '[init.svc.adbd]: [stopped]' biciminde;
# bu yuzden '^init.svc' ile grep BOS doner. '[init.svc' kullan.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote servisi gercekten TANIMLI mi ==="
A 'getprop | grep "\[init.svc" | wc -l'
A 'getprop | grep -i "zygote" | head -8'
echo ""
echo "=== 2) HANGI dosya master rc? (import icerenler) ==="
A 'grep -rl "^import" /system/etc/init/*.rc 2>/dev/null | head -5'
echo ""
echo "=== 3) zygote import satiri var mi (herhangi bir yerde) ==="
A 'grep -rn "zygote" /system/etc/init/*.rc 2>/dev/null | head -10'
echo ""
echo "=== 4) top-level .rc dosya sayisi ==="
A 'ls /system/etc/init/*.rc 2>/dev/null | wc -l'
A 'ls /system/etc/init/ | tail -25'