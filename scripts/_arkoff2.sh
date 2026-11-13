#!/bin/bash
# DENEY (anlik, risksiz): ro.ark.enable'i calisma aninda 0 yap.
# "Runtime type: ark runtime = 0/1" loglarinin iki farkli deger
# vermesi iki ayri yol oldugunu gosteriyor. ikisi de oluyor.
# ro.* salt-okunur AMA init erken asamada bir kez yazabiliyor.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) setprop ro.ark.enable 0 denemesi ==="
A 'setprop ro.ark.enable 0; echo "  sonuc: ro.ark.enable = [$(getprop ro.ark.enable)]"'
echo ""
echo "=== 2) setprop arsivi / bootloadera yazilabilir ro ozellikler ==="
A 'ls -l /data/property/ 2>&1 | head -3
   echo "--- resetprop/property_file var mi:"; ls /system/bin/resetprop 2>&1'