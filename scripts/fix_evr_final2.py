with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Comment out exec_start apexd-bootstrap in init.rc patching
# The rclog script patches init.rc. We need to add a patch to comment out
# exec_start apexd-bootstrap. But first, let's check if the rc patching
# handles init.rc.

# Actually, the rclog script patches rc files by bind-mounting patched versions.
# We need to add rc patches for EVR-L29 specifically.

# Fix 2: Make fix_ldconfig more robust - ensure CFG is created even on first boot
# and that it has APEX paths. The current code creates CFG but then init's
# linkerconfig overwrites it. We need to make fix_ldconfig run AFTER init's
# linkerconfig, or make our config stick.

# Actually, the real issue is that EVR-L29's init.rc has `critical` services
# (ueventd, zygote) that crash init when they can't link libraries.
# Let's patch init.rc to remove critical flags.

# Find the rclog section and add rc patches for EVR-L29
old_rclog = '''  # --- ADIM 1: rc agacini kopyala (dizin seviyesinde) -------------------------'''
new_rclog = '''  # --- EVR-L29: Patch init.rc to remove critical flags and exec_start apexd-bootstrap ---
  # ueventd and zygote are critical; if they fail to link (linker config issues),
  # init crashes. Remove critical flag so init survives service failures.
  # Also comment out exec_start apexd-bootstrap which can hang if apexd fails.
  if [ -f "$SRC/init.rc" ]; then
    sed -i 's/^service ueventd /service ueventd /' "$SRC/init.rc" 2>/dev/null
    sed -i 's/^    critical$/    # critical/' "$SRC/init.rc" 2>/dev/null
    sed -i 's/^    shutdown critical$/    # shutdown critical/' "$SRC/init.rc" 2>/dev/null
    sed -i 's/^    exec_start apexd-bootstrap$/    # exec_start apexd-bootstrap/' "$SRC/init.rc" 2>/dev/null
    m "### EVR-L29: Patched init.rc - removed critical flags and exec_start apexd-bootstrap ###"
  fi
  if [ -f "$SRC/init.zygote64_32.rc" ]; then
    sed -i 's/^    critical$/    # critical/' "$SRC/init.zygote64_32.rc" 2>/dev/null
    sed -i 's/^    shutdown critical$/    # shutdown critical/' "$SRC/init.zygote64_32.rc" 2>/dev/null
    m "### EVR-L29: Patched init.zygote64_32.rc - removed critical flags ###"
  fi

  # --- ADIM 1: rc agacini kopyala (dizin seviyesinde) -------------------------'''

if old_rclog in c:
    c = c.replace(old_rclog, new_rclog, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('EVR-L29 rc patches added')
else:
    print('RCLog ADIM 1 block not found')
    # Debug
    idx = c.find('ADIM 1: rc agacini kopyala')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')
