#!/bin/bash
# zygote SIGABRT ile crash-loop. /data/tombstones ARTIK var (ensure_data_dirs).
# En yeni tombstone zygote'ye ait mi? Abort mesaji ne?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) tombstone dosyalari ==="
A 'ls -lt /data/tombstones/ 2>&1 | head -8'
echo ""
echo "=== 2) en yenisinin kimligi ==="
T=$(A 'ls -t /data/tombstones/tombstone_[0-9]* 2>/dev/null | grep -v "\.pb" | head -1' | tr -d '\r')
echo "dosya: $T"
A "grep -E '^Cmdline:|>>>' $T 2>&1 | head -3"
echo ""
echo "=== 3) ABORT MESAJI (asil sebep) ==="
A "grep -E 'Abort message|signal ' $T 2>&1 | head -4"
echo ""
echo "=== 4) backtrace ilk 15 kare ==="
A "sed -n '/^backtrace:/,/^memory near/p' $T 2>&1 | head -17"