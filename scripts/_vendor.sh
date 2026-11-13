#!/bin/bash
# /r/system/bin/init = VENDOR ALTBAGLAMI (init: Forked subcontext for
# 'u:r:vendor_init:s0'). Alt baglam VENDOR namespace'inde calisir.
# [vendor] bolumunde bionic/libc.so yolu var mi?
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) configteki tum bolumler ==="
A "grep -n '^\[' /linkerconfig/ld.config.txt"
echo ""
echo "=== 2) [vendor] bolumunun TAM icerigi ==="
A "awk '/^\[vendor\]/{s=1;next} /^\[/{s=0} s' /linkerconfig/ld.config.txt | head -25"
echo ""
echo "=== 3) [vendor] icinde bonic/libc yolu ==="
A "awk '/^\[vendor\]/{s=1;next} /^\[/{s=0} s && /bionic|com.android.runtime/' /linkerconfig/ld.config.txt | head -5"
echo ""
echo "=== 4) bolum sayaci ==="
A "awk '/^\[/{n++} END{print n\" bolum\"}' /linkerconfig/ld.config.txt"