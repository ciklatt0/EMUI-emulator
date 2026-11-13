#!/bin/bash
# APEX art lib64 ile system lib64'yi karsilastir.
# Eksik olanlari system/lib64'ye kopyalamak LoadNativeLibrary namespace
# sorununu cozebilir (system namespace'de bulunur -> com_android_art gerek kalmaz).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'echo "=== 1) /apex/com.android.art/lib64 icerigi ==="
   /bb/ls /apex/com.android.art/lib64/ 2>&1 | /bb/head -40
   echo ""
   echo "=== 2) /system/lib64 icerigi (ilk 40) ==="
   /bb/ls /system/lib64/ 2>&1 | /bb/head -40
   echo ""
   echo "=== 3) Karsilastirma ==="
   for f in libart.so libartbase.so libartpalette-system.so libnativehelper.so \
            libandroid_runtime.so libcutils.so liblog.so libdl.so libicu.so; do
     APEX=$(/bb/ls /apex/com.android.art/lib64/$f 2>/dev/null)
     SYS=$(/bb/ls /system/lib64/$f 2>/dev/null)
     /bb/printf "  %-30s apex=%-8s system=%s\n" "$f" "${APEX:-YOK}" "${SYS:-YOK}"
   done
   echo ""
   echo "=== 4) TUM apex lib64 dosyalari system/lib64'de VAR MI ==="
   for f in $(/bb/ls /apex/com.android.art/lib64/ 2>/dev/null); do
     if [ ! -e "/system/lib64/$f" ]; then
       /bb/echo "  EKSIK: $f"
     fi
   done | /bb/head -30
   echo "  (bitis)"'
