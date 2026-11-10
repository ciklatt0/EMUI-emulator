with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove the wait_for_prop before class_start hal/core - let vendor HALs start immediately
# They'll crash initially but restart until servicemanager stabilizes
old = '''  # --- EVR-L29: Delay vendor HALs until servicemanager is ready -------------
  # vendor HALs (hwcomposer, gralloc, drm-widevine, gatekeeper) start before
  # servicemanager is ready, then crash with SIGABRT when binder registration
  # fails. Without hwcomposer, SurfaceFlinger can't display anything.
  # Fix: wait for servicemanager running before class_start hal/core.
  sed -i '/^    class_start hal$/i\    wait_for_prop init.svc.servicemanager running' "$ROOT/init.rc" 2>/dev/null
  sed -i '/^    class_start core$/i\    wait_for_prop init.svc.servicemanager running' "$ROOT/init.rc" 2>/dev/null
  echo "### EVR-L29: vendor HALs delayed until servicemanager running ###"'''

new = '''  # --- EVR-L29: vendor HALs start immediately (restart until servicemanager ready) ---
  # hwcomposer, gralloc, etc. may crash initially if servicemanager isn't ready,
  # but init will restart them. Eventually servicemanager stabilizes and they
  # stay up. Without hwcomposer, SurfaceFlinger can't display anything.
  echo "### EVR-L29: vendor HALs start immediately (restart until ready) ###"'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('wait_for_prop removed, vendor HALs start immediately')
else:
    print('ERROR: Pattern not found')
    idx = c.find('wait_for_prop')
    if idx != -1:
        print(f'Found wait_for_prop at {idx}: {repr(c[idx:idx+200])}')