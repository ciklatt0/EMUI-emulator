with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find and fix the early return in fix_ldconfig
old = '''  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    fi
  fi
  [ -f "$CFG" ] || return 0'''

new = '''  if [ ! -f "$CFG" ]; then
    if [ -s /bb/nb/ld.stock ]; then
      mkdir -p /linkerconfig 2>/bb/null
      /bb/cp /bb/nb/ld.stock "${CFG}.tmp" 2>/bb/null \
        && /bb/mv -f "${CFG}.tmp" "$CFG" 2>/bb/null
    else
      # DIKKAT (EVR-L29): ld.stock yok ve CFG yok. Sifirdan uretilmesi
      # gerekiyor. Asagidaki PATHS uretilme kodu bunu halledecek.
      m "### ld.config.txt yok ve ld.stock yok; sifirdan uretiliyor ###"
      ld_ok=0
    fi
  fi
  [ -f "$CFG" ] || {
    # CFG henüz yok ama ld_ok=0, asagidaki uretilme kodu calistiracak.
    true
  }'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('Early return fix applied')
else:
    print('Old code block not found')
    # Debug: show what's there
    idx = c.find('[ -f "$CFG" ] || return 0')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx-100:idx+100])}')
