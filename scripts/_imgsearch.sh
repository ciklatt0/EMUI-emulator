#!/bin/bash
# IKI DOSYA ROM'DA YOK:
#   /system/pandastdlib/arkstdlib.abc   (Ark VM'nin standart
#                                        kutuphanesi -- ark'in
#                                        varsayilan boot dosyasi)
#   libartbased.so                      (ark'in aradigi, dlopen
#                                        BASARISIZ olan kutuphane)
# Belki mount ETMEDIGIMIZ bir bolumdedirler. Disk imajinin
# HAM iceriginde arayalim.
IMG=/root/harmony-build/boot/system-disk.img
echo "=== imaj ==="
ls -l "$IMG" | awk '{print "  boyut:", $5}'
echo ""
echo "=== 1) 'arkstdlib' ham imajda ==="
/bb/grep -c "arkstdlib" "$IMG" 2>/dev/null || grep -a -c "arkstdlib" "$IMG" 2>/dev/null || echo "  (tarama cok yavas)"
echo ""
echo "=== 2) 'libartbased' ham imajda ==="
grep -a -c "libartbased" "$IMG" 2>/dev/null || echo "  (0 = yok)"
echo ""
echo "=== 3) 'pandastdlib' ham imajda ==="
grep -a -c "pandastdlib" "$IMG" 2>/dev/null || echo "  (0 = yok)"