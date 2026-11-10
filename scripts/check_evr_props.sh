#!/bin/bash
MOUNT=/tmp/sys-mnt-evr
mkdir -p $MOUNT
mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img $MOUNT 2>/dev/null

echo "=== system/build.prop ==="
cat $MOUNT/system/build.prop 2>/dev/null

echo ""
echo "=== system/product/build.prop ==="
cat $MOUNT/system/product/build.prop 2>/dev/null

echo ""
echo "=== init.environ.rc ==="
cat $MOUNT/init.environ.rc

umount $MOUNT