#!/bin/bash
# Zygote ~1 sn'de bir cokup yeniden doguyor (20 sn'de ~20 kez).
# Bu pencerede ciddi seviyeli (W/E/F) tum loglari toplayalim,
# zygote/app_process/AndroidRuntime/art etiketlerini onceleyerek.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) 22 sn topla ==="
A 'logcat -b all -c 2>/dev/null; /bb/sleep 22; echo "toplandi ($(logcat -d -b all 2>/dev/null | wc -l) satir)"'
echo ""
echo "=== 2) ZYIGOTE/VM etiketleri (tum pencere) ==="
A 'logcat -d -b all -v time 2>/dev/null | grep -iE "zygote|appproc|app_process|ZygoteInit|RuntimeInit|AndroidRuntime|artd|dalvik|libart|boot_progress|ClassNotFound|NoClassDef|VerifyError" | grep -v "avc:" | head -35'
echo ""
echo "=== 3) TUM E/F seviye (avc haric), zygote disi ==="
A 'logcat -d -b all -v brief 2>/dev/null | grep -E "^[EWF]/" | grep -v "avc:" | grep -viE "libteec|wifinl|HidlService|keymaster|bluetooth.audio|soundtrigger|ashmem|fmq" | head -25'
echo ""
echo "=== 4) crash tamponu ==="
A 'logcat -d -b crash 2>/dev/null | grep -E "^.*(signal|Abort message|Abort message)" | tail -8'