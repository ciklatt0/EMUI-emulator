#!/bin/bash
# [system] bolumunde GECERLI olan tum anahtarlar listesi.
# Bizim [vendor] bolumu bunlardan fazlasi iceriyor ve config i
# zehirliyor:
#   ld.config.txt:371: error: undefined namespace: /system/bin:/system/lib64
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) [system] bolumundeki TUM anahtarlar (tekilleştirilmiş) ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /=/{sub(/[ \t]*=.*/,\"\"); sub(/^[ \t]+/,\"\"); print}' /linkerconfig/ld.config.txt | sort -u"
echo ""
echo "=== 2) [system] bolumunde links/linksystem/interpreter satirlari ==="
A "awk '/^\[system\]/{s=1;next} /^\[/{s=0} s && /links|interpreter|visible|isolated|per_library/' /linkerconfig/ld.config.txt"
echo ""
echo "=== 3) 371. satir ==="
A 'sed -n "366,378p" /linkerconfig/ld.config.txt | /bb/cat -n'
echo ""
echo "=== 4) CANLI DENEY: links satirlarini sil, duzeliyor mu ==="
A 'cp /linkerconfig/ld.config.txt /tmp/ld.keep
/bb/grep -v "namespace.default.links\|namespace.default.linksystem\|namespace.default.linkshared\|namespace.default.interpreter" /tmp/ld.keep > /tmp/ld.nolinks
cp /tmp/ld.nolinks /linkerconfig/ld.config.txt
echo "silindi"; /system/bin/getprop ro.product.model 2>&1 | head -2'
echo ""
echo "=== 5) init baglaniyor mu simdi ==="
A '/system/bin/getprop init.svc.ueventd 2>&1; echo "---"; logcat -d 2>/dev/null | grep -c "undefined namespace"'