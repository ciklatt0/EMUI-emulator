#!/bin/bash
# 'ANDROID_DATA environment variable unset' -- init zygote'ye vermiyor.
# 1) init 'setenv' komutunu destekliyor mu?
# 2) Bu bir PROPERTY mi?
# 3) Diger zorunlu env: ANDROID_ROOT, ANDROID_RUNTIME_ROOT, ...
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) init'te setenv komutu var mi ==="
A 'strings /system/bin/init 2>/dev/null | grep -E "^setenv$|^setuid$|^setgid$|^setprop$|^setrlimit$|^setkeycontext$" | head -10'
echo ""
echo "=== 2) bu bir PROPERTY mi ==="
A 'getprop ANDROID_DATA; getprop ANDROID_ROOT; getprop ANDROID_RUNTIME_ROOT'
echo ""
echo "=== 3) calisan bir servisin ortami (ornek: logd) ==="
A 'p=$(pidof logd 2>/dev/null | head -1); echo "logd pid=$p"; tr "\0" "\n" < /proc/$p/environ 2>/dev/null | grep -i "ANDROID" | head -8'
echo ""
echo "=== 4) adbd ortaminda ANDROID_* var mi (bizim env'imiz) ==="
A 'p=$(pidof adbd 2>/dev/null | head -1); echo "adbd pid=$p"; tr "\0" "\n" < /proc/$p/environ 2>/dev/null | grep -iE "ANDROID|LD_" | head -8'
echo ""
echo "=== 5) init kendi ortami (kaynak) ==="
A 'tr "\0" "\n" < /proc/1/environ 2>/dev/null | grep -iE "ANDROID|PATH|LD_" | head -10'