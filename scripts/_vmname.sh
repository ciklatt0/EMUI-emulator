#!/bin/bash
# app_process64 -> libandroid_runtime.so -> AndroidRuntime::start()
# VM'yi dlopen ile yukluyor. AMA libandroid_runtime.so icinde
# "libart" dizisi YOK (olculdu). Demek baska bir isim araniyor.
# Butun kutuphane adaylarini ve VM ile ilgili tum dizeleri
# tarayalim.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== 1) libandroid_runtime.so: .so gecen BUTUN dizeler ==="
A 'strings /system/lib64/libandroid_runtime.so 2>/dev/null | grep "\.so" | sort -u | head -30'
echo ""
echo "=== 2) 'art' gecen dizeler (buyuk/kucuk) ==="
A 'strings /system/lib64/libandroid_runtime.so 2>/dev/null | grep -iE "art" | grep -viE "start|part|smart|cart|chart|partic" | head -20'
echo ""
echo "=== 3) dlopen cevresi / VM hata mesajlari ==="
A 'strings /system/lib64/libandroid_runtime.so 2>/dev/null | grep -iE "dlopen|vm |jvm|runtime|Unable to|Failed to" | head -25'
echo ""
echo "=== 4) app_process64: 'ART_RUNTIME' disinda VM ipuclari ==="
A 'strings /system/bin/app_process64 2>/dev/null | grep -iE "runtime|vm|art|jvm" | head -20'