#!/bin/bash
for f in "./update_full_base.zip" \
         "./update_full_base (1).zip" \
         "./update_full_base (2).zip" \
         "./update_full_base (3).zip"; do
  echo "=== $f ==="
  unzip -l "$f" 2>/dev/null | head -15
  echo
done
