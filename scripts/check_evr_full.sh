#!/bin/bash
set -e
MOUNT=/tmp/sys-mnt-evr
mkdir -p $MOUNT
mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img $MOUNT

echo "=== Root listing ==="
ls -la $MOUNT/

echo ""
echo "=== init.rc ==="
cat $MOUNT/init.rc

echo ""
echo "=== init.zygote64_32.rc ==="
cat $MOUNT/init.zygote64_32.rc

echo ""
echo "=== build.prop files ==="
find $MOUNT -name "build.prop" 2>/dev/null

echo ""
echo "=== default.prop ==="
cat $MOUNT/default.prop 2>/dev/null

echo ""
echo "=== system/bin/app_process64 ==="
ls -la $MOUNT/system/bin/app_process64 2>/dev/null
readelf -d $MOUNT/system/bin/app_process64 2>/dev/null | grep NEEDED

umount $MOUNT