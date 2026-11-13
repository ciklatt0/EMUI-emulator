#!/bin/bash
S="$(dirname "$0")/81-boot-zygote.sh"
echo "=== init.environ.rc heredoc sinirlari ==="
grep -n 'init.environ.rc' "$S" | head -5
echo "--- RC_EOF satirlari:"
grep -n '^RC_EOF' "$S" | head -5
echo "--- heredoc baslangici:"
grep -n 'cat >"\$ROOT/init.environ.rc"' "$S" | head -2