with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add wait_for_prop servicemanager.ready before class_start hal/core in the patched init.rc
old = '''on property:sys.boot_completed=1
    start bootanimation
UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"'''

new = '''on property:sys.boot_completed=1
    start bootanimation
UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"

  # --- EVR-L29: Delay vendor HALs until servicemanager is ready -------------
  # vendor HALs (hwcomposer, gralloc, drm-widevine, gatekeeper) start before
  # servicemanager is ready, then crash with SIGABRT when binder registration
  # fails. Without hwcomposer, SurfaceFlinger can't display anything.
  # Fix: wait for servicemanager running before class_start hal/core.
  sed -i '/^    class_start hal$/i\    wait_for_prop init.svc.servicemanager running' "$ROOT/init.rc" 2>/dev/null
  sed -i '/^    class_start core$/i\    wait_for_prop init.svc.servicemanager running' "$ROOT/init.rc" 2>/dev/null
  echo "### EVR-L29: vendor HALs delayed until servicemanager running ###"'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('servicemanager wait added before vendor HALs')
else:
    print('ERROR: Pattern not found')
    idx = c.find('UI_EOF')
    if idx != -1:
        print(f'Found UI_EOF at {idx}: {repr(c[idx:idx+200])}')