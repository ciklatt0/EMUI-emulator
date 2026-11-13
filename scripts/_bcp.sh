#!/bin/bash
# zygote: boot_progress_start SONRASI HICBIR SEY yok.
#   -> VM kurulmus ama PRELOAD (sinif yukleme) baslamamis.
# Preload, bootclasspath.pb icindeki HER YOLU acar. Yollardan
# biri yoksa preload sessizce basarisiz olabilir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) bootclasspath.pb icerigi (TUM yollar) ==="
A '/system/bin/toybox strings /system/etc/classpaths/bootclasspath.pb 2>/dev/null | grep "^/" | head -30'
echo ""
echo "=== 2) bu yollardan hangileri VAR, hangileri YOK ==="
A 'for f in $(/system/bin/toybox strings /system/etc/classpaths/bootclasspath.pb 2>/dev/null | grep "^/"); do
   [ -f "$f" ] && echo "  VAR  $f" || echo "  YOK  $f"
 done'