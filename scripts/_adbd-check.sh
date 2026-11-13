#!/bin/bash
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "--- /apex/com.android.adbd ile ilgili tum satirlar ---"
grep -n 'com.android.adbd' "$F" | head -20
echo ""
echo "--- APEX mount blogu (hepsi) ---"
grep -n 'APEX mount\|/apex/.* basarili\|mount -t ext4.*apex' "$F" | head -10
echo ""
echo "--- ensure_apex / apex denetleyici ciktisi ---"
grep -n 'apex=' "$F" | tail -5