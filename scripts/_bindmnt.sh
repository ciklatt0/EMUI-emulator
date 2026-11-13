#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F"
echo ""
echo "=== 1) /system bind mount SONUCU ==="
grep -aE "bind mount olarak baglandi|bind BASARISIZ" "$F" | tail -2 | sed 's/\[[^]]*\] //' | cut -c1-120
echo ""
echo "=== 2) CANNOT LINK dagilimi ==="
grep -ao 'CANNOT LINK EXECUTABLE "[^"]*"' "$F" | sed 's/.*"\(.*\)"/\1/' | sort | uniq -c | sort -rn | head -8
echo ""
echo "=== 3) linkerconfig uyarisi ==="
grep -ac "failed to find generated linker" "$F"
echo ""
echo "=== 4) init mesajlari (son 10) ==="
grep -a "init:" "$F" | grep -av "avc:" | tail -10 | sed 's/\[[^]]*\] //' | cut -c1-150
echo ""
echo "=== 5) nabiz ==="
grep -a "### nabiz" "$F" | tail -1 | sed 's/\[[^]]*\] //' | cut -c1-350