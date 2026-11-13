#!/bin/bash
# /data BOS. on post-fs-data mkdir calismadi mi, yoksa /data
# sonradan yeniden mount mi edildi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) /data mount ==="
A 'cat /proc/mounts | grep " /data "'
echo ""
echo "=== 2) boot logunda post-fs-data / mkdir izleri ==="
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
grep -iE "mkdir|post-fs-data|zygote-start" "$F" 2>/dev/null | head -10
echo ""
echo "=== 3) init.environ.rc disari sizdi mi (bind mount) ==="
A 'ls -l /init.environ.rc; md5sum /init.environ.rc 2>&1'
echo ""
echo "=== 4) mkdir simdi calisiyor mu (adb uzerinden) ==="
A 'mkdir -p /data/dalvik-cache/arm64 && echo "ADBD MKDIR OK"'
echo ""
echo "=== 5) /data su an ==="
A 'ls -la /data 2>&1 | head -8'