#!/usr/bin/env bash
# API yuzeyini cikarir (121-export-api.py icin sarmalayici).
#
# WSL2 yasam dongusu nedeniyle tarama, agac bu OTURUMDA kurulu degilse bos
# donuyor. 120-library-scan.sh ile ayni onlem.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="/root/harmony-build/tree"

mountpoint -q "$TREE/rootfs" 2>/dev/null || bash "$HERE/100-usable-rootfs.sh" >/dev/null 2>&1
mountpoint -q "$TREE/rootfs" 2>/dev/null || { echo "HATA: agac kurulamadi"; exit 1; }

exec python3 "$HERE/121-export-api.py"