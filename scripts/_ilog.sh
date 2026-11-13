#!/bin/bash
# /init'in stdout'u seri loga dusuyor mu? (/init iki bolumde
# calisiyor: erken bolum + supervisor dongusu)
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "log: $F ($(wc -l < "$F") satir)"
echo ""
echo "=== 1) /init stdout ornegimiz: SELinux basligi ==="
grep -ac 'SELinux' "$F"
echo ""
echo "=== 2) /data ile ilgili satirlar ==="
grep -a -- '/data' "$F" | head -10 | cut -c1-140
echo ""
echo "=== 3) mountapex/tmpfs izleri ==="
grep -a 'tmpfs' "$F" | head -8 | cut -c1-140
echo ""
echo "=== 4) ensure_data_dirs 'zaten mountlu' mesaji ==="
grep -a 'yeniden baglanmadi\|icerik korunuyor\|tmpfs baglandi\|MOUNT BASARISIZ\|blok cihaz degil' "$F" | head -8 | cut -c1-140