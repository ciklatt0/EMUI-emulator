#!/bin/bash
# system_server (18522) fork OLDU ama bir dlopen'da coktu.
# Hangi .so'yu yukleyemedi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) tombstone var mi ==="
A 'ls -lt /data/tombstones/ 2>&1 | head -6'
echo ""
echo "=== 2) son tombstone: kim + sebep ==="
T=$(A 'ls -t /data/tombstones/tombstone_[0-9]* 2>/dev/null | grep -v pb | head -1' | tr -d '\r')
echo "dosya=$T"
A "grep -E '^Cmdline:|Abort message|signal |>>>' $T 2>&1 | head -5"
echo ""
echo "=== 3) logcat: dlopen hatasi / system_server ==="
A 'logcat -d -b all 2>/dev/null | grep -viE "avc:" | grep -iE "dlopen|cannot locate|not found|system_server|SystemServer|dlopen failed" | tail -15'
echo ""
echo "=== 4) surucu: tracefs + /vendor ses HAL ==="
A 'mount | grep -iE "tracefs|debugfs" | head -3; ls /sys/kernel/tracing 2>&1 | head -2'