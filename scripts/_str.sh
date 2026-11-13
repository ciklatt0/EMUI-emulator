#!/bin/bash
# app_process64 16224 bayt. TUM dizeleri kisa bir liste olur ve
# Huawei'nin bu ikiliye ne yaptigini gosterir.
HERE="$(cd "$(dirname "$0")" && pwd)"
A() { bash "$HERE/adb.sh" sh "$1" 2>&1 | tr -d '\r'; }

echo "=== app_process64 TUM dizeleri (>=4 karakter) ==="
A '/system/bin/toybox strings -n 4 /system/bin/app_process64 2>/dev/null | head -120'