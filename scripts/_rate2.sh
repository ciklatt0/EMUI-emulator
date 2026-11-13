#!/bin/bash
# CANNOT LINK HANGI ikililerde ve HIZINDA? 90 sn'lik oran olcumu.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'logcat -c 2>/dev/null; echo "logcat temizlendi"'
sleep 90
echo ""
echo "=== 90 saniyede CANNOT LINK dagilimi ==="
A 'logcat -d 2>/dev/null | grep "CANNOT LINK" | sed "s/.*EXECUTABLE \"//;s/\".*//" | sort | uniq -c | sort -rn'
echo ""
echo "=== 90 saniyede toplam ==="
A 'logcat -d 2>/dev/null | grep -c "CANNOT LINK"'
echo ""
echo "=== vendor alt baglami kac kez fork edildi ==="
A 'logcat -d 2>/dev/null | grep -c "Forked subcontext"'
echo ""
echo "=== servis durumlari ==="
A 'for s in adbd zygote surfaceflinger servicemanager hwservicemanager vndservicemanager audioserver cameraserver; do echo -n "$s="; getprop init.svc.$s; echo; done'
echo ""
echo "=== calisan servis sayisi ==="
A 'getprop | grep "\[init.svc" | grep -c running'