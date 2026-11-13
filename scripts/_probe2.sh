#!/bin/bash
# arkprobe servisini calistir ve /data/dltrace.log'u oku.
# Bu kez izleyici dosyaya yaziyor (stdio_to_kmsg ciktiyi
# kaciriyordu). DIKKAT: bb/supervise her turde dltrace.so'yu
# /data'ya kopyaliyor ama LOG DOSYASINI silmiyor; o yuzden once
# elle temizliyoruz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) log dosyasini temizle ==="
A 'rm -f /data/dltrace.log; ls -l /data/dltrace.so 2>&1 | head -1; echo "  log temizlendi"'
echo ""
echo "=== 2) gurultuyu kes ==="
A 'setprop ctl.stop arkinit 2>/dev/null; setprop ctl.stop zygote 2>/dev/null
   setprop ctl.stop arkprobe 2>/dev/null; /bb/sleep 3
   echo "  arkinit=[$(getprop init.svc.arkinit)] zygote=[$(getprop init.svc.zygote)] arkprobe=[$(getprop init.svc.arkprobe)]"'
echo ""
echo "=== 3) arkprobe calistir ==="
A 'setprop ctl.start arkprobe; /bb/sleep 15
   echo "  svc=[$(getprop init.svc.arkprobe)]"'
echo ""
echo "=== 4) /data/dltrace.log (ARK YOLUNUN IZI) ==="
A 'if [ -f /data/dltrace.log ]; then
     echo "  boyut: $(wc -c < /data/dltrace.log) bayt, $(wc -l < /data/dltrace.log) satir"
     echo "  --- TAM ICERIK:"
     /bb/head -60 /data/dltrace.log | sed "s/^/    /"
   else
     echo "  LOG DOSYASI YOK -- dltrace hic yuklenmedi veya acamadi"
   fi'