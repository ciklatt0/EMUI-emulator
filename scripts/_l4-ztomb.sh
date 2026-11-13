#!/bin/bash
# zygote dogru komutla basliyor ama cokuyor. Tombstone oku.
# Ayrica: ro.crypto.state BOS -> 'on zygote-start && property:
# ro.crypto.state=unencrypted' tetiklenmiyor, yani zygote otomatik
# baslamiyor (biz elle baslattik).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) en yeni tombstone ==="
A 'ls -t /data/tombstones/ 2>/dev/null | head -4'
echo ""
echo "=== 2) zygote tombstone OZETI ==="
T=$(A 'ls -t /data/tombstones/tombstone_[0-9][0-9] 2>/dev/null | head -1' | tr -d '\r')
echo "dosya: $T"
A "grep -A4 'Cmdline:' $T 2>/dev/null | head -8"
A "grep -E 'Abort message|signal |>>>' $T 2>/dev/null | head -5"
echo ""
echo "=== 3) backtrace (ilk 12 kare) ==="
A "sed -n '/backtrace/,/memory near/p' $T 2>/dev/null | head -14"