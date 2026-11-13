#!/bin/bash
# UI (L7) icin eksik olan NE? Her katmani tek tek olc.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "===== A) GRAFIK / EKRAN ALTTEKISI ====="
echo "-- display cihazlari:"
A 'ls /dev/dri 2>&1; ls /dev/fb* 2>&1'
echo "-- framebuffer / DRM sysfs:"
A 'ls /sys/class/drm 2>&1 | head -5; cat /sys/class/graphics/fb0/name 2>&1'
echo "-- GRALLOC + EGL/GLES kutuphaneleri:"
A 'ls /system/lib64/ 2>/dev/null | grep -iE "gralloc|EGL|GLESv|gbm|virgl" | head -10'
echo "-- HWComposer HAL:"
A 'ls /vendor/lib64/hw/ 2>/dev/null | grep -iE "composer|gralloc" | head -6'

echo ""
echo "===== B) SUREC KATMANI ====="
echo "-- zygote/system_server/surfaceflinger/bootanim:"
A 'for s in zygote surfaceflinger bootanim bootanimation; do echo -n "$s="; getprop init.svc.$s; done'
A 'getprop sys.boot_completed; getprop dev.bootcomplete; getprop ro.crypto.state'
echo "-- surfaceflinger ikilisi var mi:"
A 'ls /system/bin/surfaceflinger /system/bin/bootanimation 2>&1'

echo ""
echo "===== C) BINDER + SERVISLER ====="
echo "-- binder:"
A 'ls -l /dev/binder /dev/hwbinder /dev/vndbinder 2>&1'
echo "-- calisan servisler (running):"
A 'getprop | grep "\[init.svc" | grep running | head -20'

echo ""
echo "===== D) GIRIS ====="
A 'ls /dev/input 2>&1 | head -6'