with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Replace the linker64 bind-mount block - try binding to /system/bin/linker64 directly
old = '''  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file. Bind-mount it over the broken symlink path so
  # servicemanager and all dynamically-linked binaries can run.
  if [ -f /system/bin/bootstrap/linker64 ] && [ ! -e /apex/com.android.runtime/bin/linker64 ]; then
    mkdir -p /apex/com.android.runtime/bin 2>/dev/null
    mount -o bind /system/bin/bootstrap/linker64 /apex/com.android.runtime/bin/linker64 2>/dev/null \
      && echo "### EVR-L29: linker64 bind-mount applied ###"
  fi'''

new = '''  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file (1.5 MB). Copy it to initramfs and bind-mount over
  # the broken symlink so servicemanager and all dynamically-linked binaries
  # can run.
  if [ -f /system/bin/bootstrap/linker64 ]; then
    cp /system/bin/bootstrap/linker64 /linker64 2>/dev/null
    mount -o bind /linker64 /system/bin/linker64 2>/dev/null \
      && echo "### EVR-L29: linker64 bind-mount applied ###"
  fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('linker64 bind-mount to /system/bin/linker64 added')
else:
    print('ERROR: Pattern not found')
    idx = c.find('Fix linker64 symlink')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+300])}')