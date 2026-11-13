#!/bin/bash
# app_process64 HICBIR cikti vermiyor -- ne class-not-found ne
# usage. Ya ikili degistirilmis ya da UZERINE bir sey baglanmis.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /system altindaki TUM mount'lar ==="
A 'cat /proc/mounts | grep -E " /system| /r|overlay" | head -20'
echo ""
echo "=== 2) /system/bin gercekten mount edilmis mi ==="
A 'mountpoint -q /system/bin && echo "system/bin MOUNT NOKTASI" || echo "system/bin mount degil"'
echo ""
echo "=== 3) app_process64 gercek dosya mi, inode ve boyut ==="
A 'ls -li /system/bin/app_process64; /bb/stat -c "inode=%i size=%s links=%h" /system/bin/app_process64 2>&1'
echo ""
echo "=== 4) ilk 64 bayt (ELF basligi) ==="
A '/bb/dd if=/system/bin/app_process64 bs=1 count=64 2>/dev/null | /bb/od -An -tx1 | head -4'
echo ""
echo "=== 5) app_process64 gercekten calisiyor mu (beyaz dongu testi) ==="
A 'cd /; export ANDROID_DATA=/data; timeout 6 /system/bin/app_process64 -Xzygote /system/bin --zygote &
   P=$!; sleep 2; echo "surec durumu: $(cut -d" " -f3 /proc/$P/stat 2>/dev/null)"; wait $P; echo "RC=$?"'