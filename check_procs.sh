#!/system/bin/sh
echo "=== Calisan surecler (system_server/zygote/app_process) ==="
for d in /proc/[0-9]*; do
  E=$(readlink $d/exe 2>/dev/null)
  case "$E" in
    *system_server*) echo "  SYSTEM_SERVER: PID=$(basename $d) exe=$E" ;;
    *app_process*) echo "  APP_PROCESS: PID=$(basename $d) exe=$E" ;;
    *zygote*) echo "  ZYGOTE: PID=$(basename $d) exe=$E" ;;
  esac
done
echo ""
echo "=== logcat: system_server/zygote/art ile ilgili son 20 satir ==="
logcat -d -b all 2>/dev/null | grep -iE "system_server|zygote|ZygoteInit|runtime|artd|boot_preload" | grep -v "avc:" | tail -20
echo ""
echo "=== logcat: hata/fatal ile ilgili ==="
logcat -d -b all 2>/dev/null | grep -iE "FATAL|F/.*:|Can't|cannot|failed.*lib|no.*found" | grep -v "avc:" | tail -20
