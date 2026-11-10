with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

print("=== Current state check ===")

# Check if output redirect exists
old_redirect = 'exec 1>>"$INITLOG" 2>&1'
if old_redirect in content:
    print("FOUND: output redirect to /bb/init.out")
else:
    print("NOT FOUND: output redirect to /bb/init.out")

# Check if system_server service exists in init.rc section
if 'service system_server' in content:
    print("FOUND: service system_server in script")
else:
    print("NOT FOUND: service system_server in script")

# Check if start system_server exists
if 'start system_server' in content:
    print("FOUND: start system_server in script")
else:
    print("NOT FOUND: start system_server in script")

# Fix 1: Change output redirect to also write to /dev/kmsg
# Replace: exec 1>>"$INITLOG" 2>&1
# With:    exec 1>>"$INITLOG" 2>&1   (keep file) + also write to /dev/kmsg
# We'll use tee approach: write to file AND kmsg
old_redirect_block = '''INITLOG=/bb/init.out
: > "$INITLOG" 2>/dev/null
exec 1>>"$INITLOG" 2>&1
echo "### /init cikti kanali -> $INITLOG (denetleyici kmsg'e bosaltacak) ###"'''

new_redirect_block = '''INITLOG=/bb/init.out
: > "$INITLOG" 2>/dev/null
# Write to BOTH /bb/init.out AND /dev/kmsg so we can see debug output in boot log
exec 1> >(tee -a "$INITLOG" /dev/kmsg 2>&1) 2>&1
echo "### /init cikti kanali -> $INITLOG + /dev/kmsg ###"'''

if old_redirect_block in content:
    content = content.replace(old_redirect_block, new_redirect_block, 1)
    print("FIX 1: Output redirect updated to tee to /dev/kmsg")
else:
    print("WARNING: Could not find exact redirect block, trying simpler replacement")
    # Try simpler replacement
    old_simple = 'exec 1>>"$INITLOG" 2>&1'
    new_simple = 'exec 1> >(tee -a "$INITLOG" /dev/kmsg 2>&1) 2>&1'
    if old_simple in content:
        content = content.replace(old_simple, new_simple, 1)
        print("FIX 1: Simple redirect replacement done")
    else:
        print("ERROR: Neither redirect pattern found")

# Fix 2: Add system_server service to init.rc after servicemaker start
# Find where init.rc is patched and add system_server start
old_svc_start = '''  echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done

  # --- EVR-L29: Start system_server after servicemaker in init.rc ---
  sed -i '/[[:space:]]*start servicemanager[[:space:]]*$/a\\    start system_server' "$ROOT/init.rc" 2>/dev/null

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---'''

new_svc_start = '''  echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done

  # --- EVR-L29: Start system_server after servicemaker in init.rc ---
  /bb/echo "### EVR-L29: adding system_server service to init.rc ###" >/dev/kmsg 2>&1
  if ! /bb/grep -q 'service system_server' "$ROOT/init.rc" 2>/dev/null; then
    cat >> "$ROOT/init.rc" <<'SS_EOF'

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server com.android.server.SystemServer
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg
SS_EOF
    /bb/echo "### EVR-L29: system_server service added ###" >/dev/kmsg 2>&1
  fi
  # Start system_server right after servicemaker
  sed -i '/[[:space:]]*start servicemanager[[:space:]]*$/a\\    start system_server' "$ROOT/init.rc" 2>/dev/null
  /bb/echo "### EVR-L29: start system_server appended after servicemaker ###" >/dev/kmsg 2>&1

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---'''

if old_svc_start in content:
    content = content.replace(old_svc_start, new_svc_start, 1)
    print("FIX 2: system_server service + start added to init.rc")
else:
    print("WARNING: Could not find svc_start pattern, trying alternate")
    # Try simpler pattern
    old_alt = '''  echo "### EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---'''.replace('---', '-')
    # Just add system_server before the UI section
    if '# --- EVR-L29: UI servisleri ekle' in content:
        content = content.replace(
            '# --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---',
            '''  # --- EVR-L29: Start system_server after servicemaker in init.rc ---
  /bb/echo "### EVR-L29: adding system_server service to init.rc ###" >/dev/kmsg 2>&1
  if ! /bb/grep -q 'service system_server' "$ROOT/init.rc" 2>/dev/null; then
    cat >> "$ROOT/init.rc" <<'SS_EOF'

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server com.android.server.SystemServer
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg
SS_EOF
    /bb/echo "### EVR-L29: system_server service added ###" >/dev/kmsg 2>&1
  fi
  # Start system_server right after servicemaker
  sed -i '/[[:space:]]*start servicemanager[[:space:]]*$/a\\    start system_server' "$ROOT/init.rc" 2>/dev/null
  /bb/echo "### EVR-L29: start system_server appended after servicemaker ###" >/dev/kmsg 2>&1

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---''', 1)
        print("FIX 2: Added via alternate pattern")
    else:
        print("ERROR: Could not find UI servisleri pattern either")

# Fix 3: Add kmsg echo to linker64 fix section
old_linker = '''  /bb/echo "### EVR-L29: reaching linker64 fix ###"
  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file (1.5 MB). Copy it over the broken symlink so
  # servicemaker and all dynamically-linked binaries can run.
  # MUST run AFTER /system is bind-mounted (above), otherwise the mount covers
  # our overlay. MUST run BEFORE exec init so servicemaker sees it.
  if [ -f /system/bin/bootstrap/linker64 ]; then
    mkdir -p /system-bin-tmp 2>/dev/null
    cp -a /system/bin/* /system-bin-tmp/ 2>/dev/null
    rm -f /system-bin-tmp/linker64 2>/dev/null
    cp /system/bin/bootstrap/linker64 /system-bin-tmp/linker64 2>/dev/null
    mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null       && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"
    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###"
  fi'''

new_linker = '''  /bb/echo "### EVR-L29: reaching linker64 fix ###" >/dev/kmsg 2>&1
  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file (1.5 MB). Copy it over the broken symlink so
  # servicemaker and all dynamically-linked binaries can run.
  # MUST run AFTER /system is bind-mounted (above), otherwise the mount covers
  # our overlay. MUST run BEFORE exec init so servicemaker sees it.
  /bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###" >/dev/kmsg 2>&1
  if [ -f /system/bin/bootstrap/linker64 ]; then
    /bb/echo "### EVR-L29: bootstrap/linker64 FOUND ###" >/dev/kmsg 2>&1
    mkdir -p /system-bin-tmp 2>/dev/null
    cp -a /system/bin/* /system-bin-tmp/ 2>/dev/null
    rm -f /system-bin-tmp/linker64 2>/dev/null
    cp /system/bin/bootstrap/linker64 /system-bin-tmp/linker64 2>/dev/null
    mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \
      && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###" >/dev/kmsg 2>&1
    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###" >/dev/kmsg 2>&1
  else
    /bb/echo "### EVR-L29: ERROR: bootstrap/linker64 NOT FOUND! ###" >/dev/kmsg 2>&1
  fi'''

if old_linker in content:
    content = content.replace(old_linker, new_linker, 1)
    print("FIX 3: Linker64 section updated with kmsg output")
else:
    print("WARNING: Could not find linker64 block")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("All fixes applied!")
