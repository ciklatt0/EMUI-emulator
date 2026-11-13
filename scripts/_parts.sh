#!/bin/bash
# Offset -> bolum eslestirmesi:
#   arkstdlib    8407940142 / 8407941829
#   pandastdlib  8407940142 / 8407941817
#   libartbased  8010869464 / 8032785312
# Bolum sinirlari (bayt = sektor*512):
#   p9 : 7972333312 .. 8043626496   (68M)
#   p29: 8255442944 .. 9329180672   (1G)   <- /data
# Yani arkstdlib/pandastdlib p29'da (/data), libartbased p9'da.
# Ama /data'yi mount edip aradik ve BULAMADIK. Dogrulayalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) konakta mountlu bolumler ==="
A 'grep -E "vda|/r " /proc/mounts | head -20'
echo ""
echo "=== 2) tum blok cihazlar ve mount durumu ==="
A 'for n in $(seq 1 30); do
   D=/devblk/vda$n
   [ -b "$D" ] || continue
   M=$(/bb/grep " $D " /proc/mounts 2>/dev/null | /bb/awk "{print \$2}")
   printf "  vda%-3s %-18s %s\n" "$n" "${M:-<MONT DEGIL>}" "$([ -n "$M" ] && echo "" || echo "BOS!")"
 done'