#!/bin/bash
# zygote SURECI HIC YOK (init.svc.zygote=running bayat).
# 1) Gercekten hangi surecler ayakta
# 2) init zygote'yi NASIL baslatiyor (bizim urettigimiz rc)
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) TUM surecler (PID 1. sutun!) ==="
A 'ps -A 2>/dev/null | head -1; ps -A 2>/dev/null | tail -n +2 | awk "{print \$1, \$NF}" | head -40'
echo ""
echo "=== 2) zygote/app_process adli surec var MI ==="
A 'for p in /proc/[0-9]*; do c=$(tr "\0" " " < $p/cmdline 2>/dev/null); case "$c" in *zygote*|*app_process*) echo "$(basename $p): $c";; esac; done | head -6; echo "(bos ise yok)"'
echo ""
echo "=== 3) init rc dosyamizda zygote tanimi ==="
A 'grep -rn "service zygote" /system/etc/init/*.rc /init.environ.rc 2>/dev/null | head -5'
echo ""
echo "=== 4) zygote servisinin tam blogu ==="
A 'awk "/^service zygote/,/^}/" /init.environ.rc 2>/dev/null | head -30'
echo ""
echo "=== 5) bizim olusturdugumuz rclog ciktisi (rc dizini) ==="
A 'ls -t /system/etc/init/ 2>/dev/null | head -12'
echo ""
echo "=== 6) zygote ile ilgili logcat (AVC haric) ==="
A 'logcat -d -b all 2>/dev/null | grep -iE "zygote|app_process|appproc|START .*Init" | grep -v "avc:" | tail -20'