#!/bin/bash
# Tum dltrace log'unun sonunu ve tum tumstone'u okuyup,
# hangi kitaplik/calisma cokuyor, kesin olarak bulalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

A 'echo "=== 1) dltrace.log TAMAMI ==="
   /bb/cat /data/dltrace.log 2>/dev/null | /bb/wc -l
   /bb/cat /data/dltrace.log 2>/dev/null | /bb/tail -30
   echo ""
   echo "=== 2) son tombstone dosyasi ==="
   T=$(/bb/ls /data/tombstones/ 2>/dev/null | /bb/sort -r | /bb/head -1)
   echo "  dosya: $T"
   if [ -n "$T" ]; then
     /bb/cat /data/tombstones/$T 2>/dev/null | /bb/head -80
   fi
   echo ""
   echo "=== 3) logcat crash buffer'dan dalvikvm64 abort'i ==="
   logcat -d -b crash 2>/dev/null | grep -iE "dalvikvm64|abort|F/libc|F/art|F/runtime|F/DEBUG" | /bb/head -10 | cut -c1-200'