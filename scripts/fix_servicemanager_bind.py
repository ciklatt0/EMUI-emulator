with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add bind mount for patched servicemanager.rc before exec /system/bin/init
old = '''exec /system/bin/init "$@"
INIT_EOF'''

new = '''# --- EVR-L29: Bind-mount patched servicemanager.rc over original -----------
  # Override the minimal servicemanager.rc on EROFS with our patched version
  # (class core/user/group added). This must be done BEFORE exec init so that
  # init reads the patched version when parsing rc files.
  if [ -f /servicemanager.rc ]; then
    mount -o bind /servicemanager.rc /system/etc/init/servicemanager.rc 2>/dev/null \
      && echo "### EVR-L29: servicemanager.rc bind-mount overlay applied ###"
  fi

exec /system/bin/init "$@"
INIT_EOF'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('servicemanager.rc bind-mount added to /init')
else:
    print('ERROR: Pattern not found')
    idx = c.find('exec /system/bin/init')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+100])}')