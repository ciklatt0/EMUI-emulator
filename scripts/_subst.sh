#!/bin/bash
S="$(dirname "$0")/81-boot-zygote.sh"
echo "=== 1) __DATADEV_PART__ yerleri ==="
grep -n '__DATADEV_PART__' "$S"
echo ""
echo "=== 2) sed ikameleri (hangi dosyaya) ==="
grep -n 'sed -i' "$S" | grep '__DAT'
echo ""
echo "=== 3) ensure_data_docs yeri ==="
grep -n 'ensure_data_dirs' "$S"