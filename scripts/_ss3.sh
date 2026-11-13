#!/bin/bash
# system_server'in son hali. Zygote fork ediyordu, sonra bir
# dlopen'da cokuyordu. Bu kosuda ne kadar ilerledi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) system_server PID'leri ve durum ==="
A 'ps -A 2>/dev/null | grep -iE "system_server|zygote" | head -6'
echo ""
echo "=== 2) son system_server izleri (tum buffer) ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:|wificond|HidlService" | grep -iE "boot_progress|SystemServer|system_server|PackageManager|ActivityManager" | tail -12'
echo ""
echo "=== 3) dlopen/cannot-locate hatalari ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "cannot locate|dlopen failed|cannot load|not found: needed" | sort | uniq -c | sort -rn | head -10'
echo ""
echo "=== 4) vendor subcontext durumu ==="
A 'logcat -d 2>/dev/null | grep -cE "CANNOT LINK EXECUTABLE \"/r/system/bin/init\""'
A 'getprop init.svc.hwservicemanager; getprop init.svc.servicemanager'