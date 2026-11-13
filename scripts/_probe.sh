#!/bin/bash
# arkprobe servisini calistirip SERI LOGDAN dltrace ciktisini okur.
# Bu servis init.arkinit.rc'deki arkinit'in birebir kopyasi +
# LD_PRELOAD=/data/dltrace.so. stdio_to_kmsg ile cikti seri loga
# duser.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /data/dltrace.so var MI ==="
A 'ls -l /data/dltrace.so 2>&1 | head -1'
echo ""
echo "=== 2) gurultuyu kes ==="
A 'setprop ctl.stop arkinit 2>/dev/null; setprop ctl.stop zygote 2>/dev/null; /bb/sleep 2
   echo "  arkinit=[$(getprop init.svc.arkinit)] zygote=[$(getprop init.svc.zygote)]"'
echo ""
echo "=== 3) arkprobe calistir (seri logu temizle ONCE) ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
: > /dev/null
echo "  log: $F  (bayat: $(wc -c < "$F") bayt)"
A 'setprop ctl.start arkprobe; /bb/sleep 12; echo "  svc=[$(getprop init.svc.arkprobe)]"'