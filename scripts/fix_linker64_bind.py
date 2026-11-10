with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add linker64 bind-mount before exec /system/bin/init
old = '''  if [ -f /servicemanager.rc ]; then
    mount -o bind /servicemanager.rc /system/etc/init/servicemanager.rc 2>/dev/null \
      && echo "### EVR-L29: servicemanager.rc bind-mount overlay applied ###"
  fi

exec /system/bin/init "$@"
INIT_EOF'''

new = '''  if [ -f /servicemanager.rc ]; then
    mount -o bind /servicemanager.rc /system/etc/init/servicemanager.rc 2>/dev/null \
      && echo "### EVR-L29: servicemanager.rc bind-mount overlay applied ###"
  fi

  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,
  # but that file doesn't exist on the EROFS partition. /system/bin/bootstrap/
  # linker64 IS a real file. Bind-mount it over the broken symlink path so
  # servicemanager and all dynamically-linked binaries can run.
  if [ -f /system/bin/bootstrap/linker64 ] && [ ! -e /apex/com.android.runtime/bin/linker64 ]; then
    mkdir -p /apex/com.android.runtime/bin 2>/dev/null
    mount -o bind /system/bin/bootstrap/linker64 /apex/com.android.runtime/bin/linker64 2>/dev/null \
      && echo "### EVR-L29: linker64 bind-mount applied ###"
  fi

exec /system/bin/init "$@"
INIT_EOF'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('linker64 bind-mount fix added')
else:
    print('ERROR: Pattern not found')
    idx = c.find('exec /system/bin/init')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+100])}')