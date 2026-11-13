#!/system/bin/sh
echo "=== TUM surecler (ilk 40) ==="
ps -A 2>/dev/null | head -40
echo ""
echo "=== system_server ara ==="
ps -A 2>/dev/null | grep -i system_server
echo "=== zygote ara ==="
ps -A 2>/dev/null | grep -i zygote
echo "=== app_process ara ==="
ps -A 2>/dev/null | grep -i app_process
echo ""
echo "=== /proc altindaki exe linkleri ==="
for d in /proc/[0-9]*; do
  E=$(readlink $d/exe 2>/dev/null)
  if [ -n "$E" ]; then
    echo "PID=$(basename $d) -> $E"
  fi
done 2>/dev/null | head -30
