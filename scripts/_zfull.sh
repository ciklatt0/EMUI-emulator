#!/bin/bash
# onceki deneyden kalan config'i (permitted'li hali) geri koy
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) config'i permitted'li haline geri koy ==="
A 'if [ -f /tmp/ld.bak ]; then cp /tmp/ld.bak /linkerconfig/ld.config.txt; echo "geri kondu"; fi
grep -c "permitted.paths += /apex" /linkerconfig/ld.config.txt'
echo ""
echo "=== 1) zygote'i ELLE calistir, tam cikti (ANDROID_DATA ile) ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system; \
   /system/bin/app_process64 -Xzygote /system/bin --zygote \
     --start-system-server --socket-name=zygote 2>&1 | head -50'