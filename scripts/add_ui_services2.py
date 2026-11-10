import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find where init.rc is patched
old = '''  # init.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.rc ]; then
    cp /tmp/sys-mnt-evr/init.rc "$ROOT/init.rc" 2>/dev/null
    # critical bayragini kaldir (init paniğini önler)
    sed -i 's/^    critical$/    # critical/' "$ROOT/init.rc" 2>/dev/null
    sed -i 's/^    shutdown critical$/    # shutdown critical/' "$ROOT/init.rc" 2>/dev/null
    # exec_start apexd-bootstrap iptal (apexd zaten mountapex ile bagli)
    sed -i 's/^    exec_start apexd-bootstrap$/    # exec_start apexd-bootstrap/' "$ROOT/init.rc" 2>/dev/null
    # start vold iptal (vold cokuyor, zygote'yi engelliyor)
    sed -i 's/^    start vold$/    # start vold/' "$ROOT/init.rc" 2>/dev/null
    # exec -- /system/bin/vdc checkpoint iptal
    sed -i 's/^    exec -- \\/system\\/bin\\/vdc/    # exec -- \\/system\\/bin\\/vdc/' "$ROOT/init.rc" 2>/dev/null
    echo "### EVR-L29: init.rc kopyalandi ve yamalandi (initramfs koku) ###"
  fi

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation, SystemUI, Launcher) ---
  # SurfaceFlinger goruntu birlestirici olmadan UI gorunmez.
  # bootanimation acilisk ekranini gosterir.
  # SystemUI ve HwLauncher6 ana ekran olusturur.
  cat >> "$ROOT/init.rc" <<'UI_EOF'

# --- EVR-L29 UI SERVICES ---
service surfaceflinger /system/bin/surfaceflinger
    class core
    user system
    group system graphics drm
    critical
    onrestart restart healthd

service bootanimation /system/bin/bootanimation
    class main
    disabled
    user root
    group root
    onrestart restart bootanimation

on property:sys.boot_completed=1
    start bootanimation
    start systemui
    start hwlauncher6

service systemui /system/bin/systemui
    class main
    disabled
    user system
    group system graphics drm
    critical

service hwlauncher6 /system/bin/app_process -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote
    class main
    disabled
    user system
    group system
UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation, systemui, hwlauncher6) ###"
fi'''

new = '''  # init.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.rc ]; then
    cp /tmp/sys-mnt-evr/init.rc "$ROOT/init.rc" 2>/dev/null
    # critical bayragini kaldir (init paniğini önler)
    sed -i 's/^    critical$/    # critical/' "$ROOT/init.rc" 2>/dev/null
    sed -i 's/^    shutdown critical$/    # shutdown critical/' "$ROOT/init.rc" 2>/dev/null
    # exec_start apexd-bootstrap iptal (apexd zaten mountapex ile bagli)
    sed -i 's/^    exec_start apexd-bootstrap$/    # exec_start apexd-bootstrap/' "$ROOT/init.rc" 2>/dev/null
    # start vold iptal (vold cokuyor, zygote'yi engelliyor)
    sed -i 's/^    start vold$/    # start vold/' "$ROOT/init.rc" 2>/dev/null
    # exec -- /system/bin/vdc checkpoint iptal
    sed -i 's/^    exec -- \\/system\\/bin\\/vdc/    # exec -- \\/system\\/bin\\/vdc/' "$ROOT/init.rc" 2>/dev/null
    echo "### EVR-L29: init.rc kopyalandi ve yamalandi (initramfs koku) ###"
  fi

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---
  # SurfaceFlinger: ekrandaki penceleri birlestiren goruntu sunucusu. UI olmaz.
  # bootanimation: acilis ekrani.
  # SystemUI ve HwLauncher6 APK'laridir; SystemServer/AMS baslatir, init degil.
  cat >> "$ROOT/init.rc" <<'UI_EOF'

# --- EVR-L29 UI SERVICES ---
service surfaceflinger /system/bin/surfaceflinger
    class core
    user system
    group system graphics drm
    critical
    onrestart restart healthd

service bootanimation /system/bin/bootanimation
    class main
    disabled
    user root
    group root
    onrestart restart bootanimation

on property:sys.boot_completed=1
    start bootanimation
UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('UI services added to initramfs init.rc')
else:
    print('ERROR: Pattern not found')
    idx = c.find('init.rc de kopyala')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+500])}')