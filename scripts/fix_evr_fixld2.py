with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()

# Replace lines 1929-1937 (0-indexed: 1928-1936)
old_block = '''  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \\
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    fi
  fi
  [ -f "$CFG" ] || return 0
'''

new_block = '''  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \\
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    else
      # DIKKAT (EVR-L29): ld.stock yok ve CFG yok. Sifirdan uretilmesi
      # gerekiyor. Asagidaki PATHS uretilme kodu bunu halledecek.
      m "### ld.config.txt yok ve ld.stock yok; sifirdan uretiliyor ###"
      ld_ok=0
    fi
  fi
  [ -f "$CFG" ] || true
'''

# Find and replace
new_lines = []
i = 0
replaced = False
while i < len(lines):
    if lines[i] == '  if [ ! -f "$CFG" ]; then\n':
        # Check if this is the right block by looking at next few lines
        block = ''.join(lines[i:i+9])
        if block == old_block:
            new_lines.append(new_block)
            i += 9
            replaced = True
            continue
    new_lines.append(lines[i])
    i += 1

if replaced:
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.writelines(new_lines)
    print('Fix applied successfully')
else:
    print('Old block not found exactly')
    # Debug: show what's actually there
    for i, line in enumerate(lines):
        if 'if [ ! -f "$CFG" ]; then' in line:
            print(f'Found at line {i+1}: {repr(lines[i])}')
            for j in range(i, min(i+9, len(lines))):
                print(f'  {j+1}: {repr(lines[j])}')
