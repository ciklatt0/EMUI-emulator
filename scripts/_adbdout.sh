#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "=== ADBD-DIAG ciktilari ==="
grep -a 'ADBD-DIAG' "$F" | sed 's/\[[^]]*\] //' | cut -c1-700
echo ""
echo "=== adbd ile ilgili tum DIAG/diag ==="
grep -aE 'DGN|dIAG|adbd' "$F" | grep -av 'avc:' | grep -a 'DIAG\|DGN' | sed 's/\[[^]]*\] //' | cut -c1-300 | tail -8