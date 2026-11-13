#!/bin/bash
# zygote64 yasama mi, zombi mi? /proc/<pid>/stat 3. alan = durum
#   R=running S=sleeping Z=zombi T=stopped
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote64 sureclerinin gercek durumu ==="
A 'for p in $(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f2); do echo "pid=$p state=$(awk "{print \$3}" /proc/$p/stat 2>/dev/null) ppid=$(awk "{print \$4}" /proc/$p/stat 2>/dev/null)"; done'
echo ""
echo "=== 2) tum app_process/zygote/system_server ==="
A 'ps -A 2>/dev/null | grep -iE "app_process|zygote|system_server" | head -8'
echo ""
echo "=== 3) servis durumlari ==="
A 'for s in zygote zygote_secondary arkinit mygote surfaceflinger; do echo -n "$s="; getprop init.svc.$s; echo; done'
echo ""
echo "=== 4) boot bayraklari ==="
A 'getprop sys.boot_completed; getprop dev.bootcomplete; getprop ro.crypto.state'
echo ""
echo "=== 5) logcat canli mi / son icerik ==="
A 'logcat -d 2>/dev/null | tail -6'