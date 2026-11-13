#!/bin/bash
# AUTOPSY'den sonra adbd bizim surecimiz, port 5555. Windows tarafindan
# adb connect dene ve QEMU'nun guest'e ulastigini dogrula.
F=$(ls -t /tmp/harmony-emulator.*.log 2>/dev/null | head -1)
B=$(wc -l < "$F")
echo "log: $F ($B satir)"
echo ""
echo "--- QEMU hostfwd canli mi ---"
ss -lntp 2>/dev/null | grep 5555 || echo "  5555 YOK"
echo ""
echo "--- WSL -> 5555 ham TCP ---"
if timeout 6 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5555' 2>/dev/null; then
  echo "  KURULDU"
else
  echo "  BASARISIZ"
fi
echo ""
echo "--- adb connect ---"
ADB="${ADB:-adb}"
if [ -x "$ADB" ]; then
  "$ADB" connect 127.0.0.1:5555 2>&1 | tail -2
  sleep 4
  "$ADB" devices 2>&1 | tail -3
else
  echo "  adb.exe yok"
fi
echo ""
echo "--- yeni log satirlari ---"
sleep 2
tail -n +$((B + 1)) "$F" | sed 's/\[[^]]*\] //' | grep -v 'avc:' | head -20 | cut -c1-200