#!/bin/bash
# KARARLI OLCUM: zygote surecini baslatip SADECE O PID'E AIT
# tum logcat satirlarini yaziyoruz. (PID= 1. sutun)
# Zaman araligi 12 sn (olcum: 5 sn ile 8 sn arasinda oluyor).
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) logcat temizle, zygote'i baslat, 12 sn sonra OKU ==="
A 'logcat -b all -c 2>/dev/null
   setprop log.tag.artd VERBOSE
   setprop log.tag.dalvikvm VERBOSE
   setprop log.tag.AndroidRuntime VERBOSE
   cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
   /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zp77 >/dev/null 2>&1 &
   ZP=$!
   /bb/sleep 12
   kill -9 $ZP 2>/dev/null; wait $ZP 2>/dev/null
   echo "ZYGOTE PID=$ZP"
   echo "--- O PIDe ait BUTUN logcat satirlari:"
   logcat -d -b all -v time 2>/dev/null | grep "( *$ZP)" | head -40
   echo "--- toplam: $(logcat -d -b all 2>/dev/null | grep -c "( *$ZP)")"'