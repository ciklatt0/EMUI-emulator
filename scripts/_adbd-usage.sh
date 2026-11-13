#!/bin/bash
B=/tmp/adbdx/bin/adbd
echo "--- minijail ile ilgili tum dizeler ---"
strings -a "$B" | grep -i 'minijail' | head -30
echo ""
echo "--- ADB_ ortam degiskenleri ---"
strings -a "$B" | grep -E '^ADB_[A-Z_]+$' | head -20
echo ""
echo "--- ro\. / persist\. ozellikleri (adb ile ilgili) ---"
strings -a "$B" | grep -E '^(ro|persist|sys)\.(adb|secure|debuggable)' | head -20
echo ""
echo "--- 'adb starting' cevresindeki mesajlar ---"
strings -a "$B" | grep -i 'adb starting\|adbd starting\|daemon\|nodaemon\|not permitted\|EPERM' | head -20