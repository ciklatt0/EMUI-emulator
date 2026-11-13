#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) zygote gercekten --start-system-server ile mi ==="
A 'for p in $(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f2); do echo "pid=$p cmd=$(/bb/tr "\0" " " < /proc/$p/cmdline 2>/dev/null)"; done'
echo ""
echo "=== 2) zygote thread sayisi ve wchan (nerede bloklu) ==="
A 'for p in $(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f2); do echo "pid=$p threads=$(ls /proc/$p/task 2>/dev/null | wc -l) state=$(cut -d" " -f3 /proc/$p/stat)"; done'
A 'p=$(ps -A 2>/dev/null | grep zygote64 | tr -s " " | cut -d" " -f2 | head -1); for t in /proc/$p/task/*; do echo "$(basename $t): $(cat $t/wchan 2>/dev/null) $(cut -d" " -f3 $t/stat 2>/dev/null)"; done 2>/dev/null | head -12'
echo ""
echo "=== 3) ARK runtime'in yuklenmesi icin gereken dosyalar ==="
A 'ls -l /system/framework/boot.art /system/framework/boot.oat /apex/com.android.art/lib64/libart.so 2>&1 | head -5'
echo ""
echo "=== 4) zygote'un preload ettigi boot classpath ==="
A 'getprop ro.bootclasspath 2>/dev/null; ls /system/framework/*.jar 2>/dev/null | wc -l'
echo ""
echo "=== 5) odex/vdex durumu ==="
A 'ls /system/framework/ 2>/dev/null | head -8'