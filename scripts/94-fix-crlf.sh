#!/usr/bin/env bash
# Bir dosyayi LF'e cevirir ve BOM siler.
#
# NEDEN: PowerShell'in 'Set-Content -Encoding UTF8' DOSYAYA BOM + CRLF
# yazar. Sonuc bash dosyayi okuyamaz:
#     line 43: syntax error near unexpected token `$'do\r''
#     line 30: set: pipefail: invalid option name
# Bu projenin .gitattributes'i .sh dosyalarini LF'de sabitliyor; ama
# PowerShell o korumayi baypas ediyor. Bu script onu geri alir.
set -uo pipefail
for f in "$@"; do
  [ -f "$f" ] || { echo "yok: $f"; continue; }
  before=$(file -b "$f")
  sed -i 's/\r$//' "$f"
  sed -i '1s/^\xEF\xBB\xBF//' "$f"
  after=$(file -b "$f")
  if bash -n "$f" 2>/dev/null; then
    printf '  [ok] %-56s %s\n' "$(basename "$f")" "$after"
  else
    printf '  [HATA] %-55s %s\n' "$(basename "$f")" "$after"
    bash -n "$f" 2>&1 | head -3 | sed 's/^/         /'
  fi
  printf '       once: %s\n' "$before"
done