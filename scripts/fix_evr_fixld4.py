with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()

# Lines 1930-1937 (1-indexed) = indices 1929-1936 (0-indexed)
# Replace with new block that doesn't return early when CFG doesn't exist
new_block = '''  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \\
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    else
      m "### ld.config.txt yok ve ld.stock yok; sifirdan uretiliyor ###"
      ld_ok=0
    fi
  fi
  [ -f "$CFG" ] || true
'''

# Replace lines 1929-1936 (0-indexed) - lines 1930-1937 (1-indexed)
new_lines = lines[:1929] + [new_block] + lines[1937:]

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.writelines(new_lines)

print('Fix applied: replaced lines 1930-1937')
