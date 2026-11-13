#!/bin/bash
# zygote elle SAGLAM, init ile baslatilinca status 0 ile OLUYOR.
# Fark: ANDROID_SOCKET_zygote (init socket) + SELinux baglami.
# logcat'te zygote'in tum izini topla (tum buffer'lar).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote PID'leri ==="
A 'ps -A 2>/dev/null | grep -i zygote | head -4'
echo ""
echo "=== 2) tum buffer: zygote + art + runtime mesajlari ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:|wificond|HidlService" | grep -iE "zygote|art |Runtime|SystemServer|preload|dalvik|boot: |GC " | tail -30'
echo ""
echo "=== 3) ZygoteInit START satirlari ve ARDASI ==="
A 'logcat -d -b all 2>/dev/null | grep -n -A 6 "START com.android.internal.os.ZygoteInit" | tail -25'
echo ""
echo "=== 4) init zygote socket tanimi (rc) ==="
A 'grep -A 14 "^service zygote " /system/etc/init/hw/init.zygote64_32.rc | head -16'