with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix 1: Replace process substitution redirect with simple /dev/kmsg redirect
# ash shell doesn't support >(...) process substitution
old_redirect = 'exec 1> >(tee -a "$INITLOG" /dev/kmsg 2>&1) 2>&1'
new_redirect = 'exec 1>/dev/kmsg 2>&1'

if old_redirect in content:
    content = content.replace(old_redirect, new_redirect, 1)
    print("FIX 1: Redirect changed to /dev/kmsg (ash-compatible)")
else:
    # Check what's actually there
    import re
    m = re.search(r'exec 1[>|].*2>&1', content)
    if m:
        print(f"Found redirect: {m.group()}")
        content = content.replace(m.group(), new_redirect, 1)
        print("FIX 1: Replaced with /dev/kmsg redirect")
    else:
        print("ERROR: No redirect found")
        # Find INITLOG line
        m2 = re.search(r'INITLOG=.*', content)
        if m2:
            print(f"Found: {m2.group()}")

# Fix 2: Make linker64 echoes explicit to /dev/kmsg (they use /bb/echo which goes to stdout)
# With exec 1>/dev/kmsg 2>&1, /bb/echo already goes to kmsg, so this should work now
# But let's add explicit /dev/kmsg redirects to the key linker64 echoes for safety
old_linker_echoes = '''  /bb/echo "### EVR-L29: reaching linker64 fix ###"
  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file (1.5 MB). Copy it over the broken symlink so
  # servicemanager and all dynamically-linked binaries can run.
  # MUST run AFTER /system is bind-mounted (above), otherwise the mount covers
  # our overlay. MUST run BEFORE exec init so servicemaker sees it.
  /bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###"
  if [ -f /system/bin/bootstrap/linker64 ]; then
    /bb/echo "### EVR-L29: bootstrap/linker64 FOUND ###"
    mkdir -p /system-bin-tmp 2>/dev/null
    cp -a /system/bin/* /system-bin-tmp/ 2>/dev/null
    rm -f /system-bin-tmp/linker64 2>/dev/null
    cp /system/bin/bootstrap/linker64 /system-bin-tmp/linker64 2>/dev/null
    mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null       && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"
    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###"
  fi'''

new_linker_echoes = '''  /bb/echo "### EVR-L29: reaching linker64 fix ###" >/dev/kmsg 2>&1
  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file (1.5 MB). Copy it over the broken symlink so
  # servicemanager and all dynamically-linked binaries can run.
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

if old_linker_echoes in content:
    content = content.replace(old_linker_echoes, new_linker_echoes, 1)
    print("FIX 3: Linker64 echoes updated with explicit /dev/kmsg")
else:
    print("WARNING: Linker64 echo pattern not found exactly")
    # Try partial replacement
    if '/bb/echo "### EVR-L29: reaching linker64 fix ###"' in content:
        content = content.replace(
            '/bb/echo "### EVR-L29: reaching linker64 fix ###"',
            '/bb/echo "### EVR-L29: reaching linker64 fix ###" >/dev/kmsg 2>&1',
            1
        )
        print("FIX 3a: Partial linker64 echo replacement done")
    if '/bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###"' in content:
        content = content.replace(
            '/bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###"',
            '/bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###" >/dev/kmsg 2>&1',
            1
        )
        print("FIX 3b: Partial linker64 checking echo replacement done")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
