#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) gozlemci baslat (60 sn, 2 sn aralikla) ==="
A 'rm -f /tmp/wlog; (/bb/sh -c "
i=0
prev=VARIM
while [ \$i -lt 30 ]; do
  if [ -f /linkerconfig/ld.config.txt ]; then cur=VARIM; else cur=YOK; fi
  if [ \"\$cur\" != \"\$prev\" ]; then
    echo \"[\$i] \$prev -> \$cur  mount=[\$(mount | grep linkerconfig | tr \\\\n \\\\|)]\" >> /tmp/wlog
    prev=\$cur
  fi
  i=\$((i+1))
  /bb/sleep 2
done
echo \"[son] mount=[\$(mount | grep linkerconfig | tr \\\\n \\\\|)]\" >> /tmp/wlog
" &) ; echo "gozlemci calisiyor"'
echo ""
echo "=== 2) 65 sn bekle ==="
sleep 65
echo ""
echo "=== 3) gozlem gunlugu ==="
A 'cat /tmp/wlog 2>&1'
echo ""
echo "=== 4) denetleyici KAYBOLMUS mesaji ==="
A 'ls -l /linkerconfig/ld.config.txt /bb/nb/ld.stock 2>&1 | head -4'