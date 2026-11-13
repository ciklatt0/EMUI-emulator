#!/bin/bash
# zygote 3 sn yasayip RC=0 ile cikiyor.
# GERCEK Android 12'de zygote /system/bin/app_process64 DEGIL,
# /apex/com.android.art/bin/app_process64 kullanir. Bu bir fark
# olabilir. Matrisi olcelim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 0) APEX app_process var mi ==="
A 'ls -l /apex/com.android.art/bin/app_process* /apex/com.android.art/lib64/libart.so 2>&1 | head -4'
echo ""
echo "=== 1) MATRIS: her bileseni 10 sn deneyip omur ve cikis kodu ==="
A 'cd /; export ANDROID_DATA=/data ANDROID_ROOT=/system
run() {
  T0=$(/bb/date +%s)
  timeout 10 "$@" >/dev/null 2>&1
  RC=$?
  T1=$(/bb/date +%s)
  echo "  $((T1-T0))sn RC=$RC  <- $*"
}
echo "[1] system app_process64 (bizim kullandigimiz):"
run /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=t1
echo "[2] APEX app_process64:"
run /apex/com.android.art/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=t2
echo "[3] sadece -Xzygote, --zygote YOK:"
run /system/bin/app_process64 -Xzygote /system/bin
echo "[4] argümansiz (kontrol):"
run /system/bin/app_process64'