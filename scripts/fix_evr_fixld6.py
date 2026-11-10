with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find the fix_ldconfig early return section and add mkdir -p /linkerconfig
old = '''  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \\
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    else
      m "### ld.config.txt yok ve ld.stock yok; sifirdan uretiliyor ###"
      ld_ok=0
    fi
  fi
  [ -f "$CFG" ] || true'''

new = '''  if [ ! -f "$CFG" ]; then
    mkdir -p /linkerconfig 2>/bb/null
    if [ -s /bb/nb/ld.stock ]; then
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \\
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    else
      m "### ld.config.txt yok ve ld.stock yok; sifirdan uretiliyor ###"
      ld_ok=0
    fi
  fi
  [ -f "$CFG" ] || true'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('mkdir -p /linkerconfig added')
else:
    print('Old block not found')
    import re
    for m in re.finditer(r'if \[ ! -f "\$CFG" \]; then', c):
        start = max(0, m.start() - 50)
        end = min(len(c), m.end() + 200)
        print(f'Found at {m.start()}: {repr(c[start:end])}')
