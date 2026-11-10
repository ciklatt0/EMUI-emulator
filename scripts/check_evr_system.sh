#!/bin/bash
mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img /tmp/sys-mnt-evr 2>/dev/null
echo "=== Root listing ==="
ls -la /tmp/sys-mnt-evr/
echo ""
echo "=== init.rc ==="
cat /tmp/sys-mnt-evr/init.rc 2>/dev/null | head -50
echo ""
echo "=== init.zygote64_32.rc ==="
cat /tmp/sys-mnt-evr/init.zygote64_32.rc 2>/dev/null
echo ""
echo "=== build.prop files ==="
find /tmp/sys-mnt-evr -name "build.prop" 2>/dev/null
echo ""
echo "=== default.prop ==="
cat /tmp/sys-mnt-evr/default.prop 2>/dev/null
echo ""
echo "=== system/bin/app_process64 ==="
ls -la /tmp/sys-mnt-evr/system/bin/app_process64 2>/dev/null
readelf -d /tmp/sys-mnt-evr/system/bin/app_process64 2>/dev/null | grep NEEDED