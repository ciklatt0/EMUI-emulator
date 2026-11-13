#!/bin/bash
# YENI HIPOTEZ: dalvikvm64'nin PT_INTERP'i APEX kendi linker'ini isaret
# ediyor olabilir. O zaman /linkerconfig/ld.config.txt okunmaz.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'echo "=== 1) dalvikvm64 PT_INTERP ==="
   readelf -l /apex/com.android.art/bin/dalvikvm64 2>/dev/null | grep -i interp || echo "  readelf yok"
   echo ""
   echo "=== 2) /apex/com.android.art altinda linker var MI ==="
   ls -l /apex/com.android.art/lib64/linker64 /apex/com.android.art/lib64/bionic/linker64 2>&1
   ls -l /apex/com.android.art/bin/linker64 2>&1 | head -2
   echo ""
   echo "=== 3) APEX'in kendi ld.config.txt'i var MI ==="
   find /apex/com.android.art -name "ld.config*" 2>/dev/null | head -5
   echo ""
   echo "=== 4) /linkerconfig altindaki tum dosyalar ==="
   ls -lR /linkerconfig/ 2>/dev/null | head -20'