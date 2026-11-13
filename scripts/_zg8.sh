#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) service zygote NEREDE tanimli? (tum agac) ==="
A 'grep -rln "service zygote" /system/etc/init/ /vendor/etc/init/ /init.environ.rc 2>/dev/null | head -6'
echo ""
echo "=== 2) taniminin tam blogu ==="
A 'for f in $(grep -rln "service zygote" /system/etc/init/ /vendor/etc/init/ /init.environ.rc 2>/dev/null | head -2); do
   echo "--- $f"
   awk "/^service zygote/,/^}/" "$f" 2>/dev/null | head -28
 done'
echo ""
echo "=== 3) logcat temizle + 15 sn bekle (2-3 zygote yeniden dogusu) ==="
A 'logcat -b all -c 2>/dev/null; /bb/sleep 15; echo bekledi'
echo ""
echo "=== 4) BU PENCEREDE zygote ile ilgili HER SEY ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "zygote|app_process|appproc|ZygoteInit|RuntimeInit|boot_progress" | grep -v "avc:" | tail -25'
echo ""
echo "=== 5) init'in zygote SERVIS cikislari ==="
A 'logcat -d -b all 2>/dev/null | grep -E "init.*(zygote|Sending signal|exited|Service)" | grep -v "avc:" | tail -10'
echo ""
echo "=== 6) ashmem ve tracefs ==="
A 'ls -l /dev/ashmem 2>&1; ls /dev/ | grep -iE "ashmem|binder" | head -5; echo "--- kernel surucusu:"; grep -c ashmem /proc/modules 2>/dev/null'