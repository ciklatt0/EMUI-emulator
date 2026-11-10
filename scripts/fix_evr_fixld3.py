with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()

# Find and replace lines 1929-1937 (0-indexed: 1928-1936)
# Line 1929: '  if [ ! -f "$CFG" ]; then\n'
# Line 1930: '    if [ -s /bb/nb/ld.stock ]; then\n'
# Line 1931: '      mkdir -p /linkerconfig 2>/bb/null\n'
# Line 1932: '      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \\\n'
# Line 1933: '        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null\n'
# Line 1934: '    fi\n'
# Line 1935: '  fi\n'
# Line 1936: '  [ -f "$CFG" ] || return 0\n'

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

# Find the start line
start_idx = None
for i, line in enumerate(lines):
    if line == '  if [ ! -f "$CFG" ]; then\n':
        # Verify it's the right block by checking next lines
        if i + 8 < len(lines) and lines[i+8] == '  [ -f "$CFG" ] || return 0\n':
            start_idx = i
            break

if start_idx is not None:
    # Replace lines start_idx through start_idx+8
    new_lines = lines[:start_idx] + [new_block] + lines[start_idx+9:]
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.writelines(new_lines)
    print(f'Fix applied at line {start_idx+1}')
else:
    print('Start line not found')
