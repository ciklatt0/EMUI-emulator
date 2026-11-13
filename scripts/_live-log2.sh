#!/bin/bash
set -u
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
echo "--- /init cikti kanalindan GELEN tum satirlar ---"
grep -n 'cikti kanali\|bb/nb\|/data\|ANDROID INIT\|HARMONYOS BOOT\|baglan\|Mount-boot\|yerlesim' "$F" | head -14