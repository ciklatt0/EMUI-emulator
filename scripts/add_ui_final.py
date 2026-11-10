with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

old = '''      echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done
  # init.environ.rc de kopyala'''

new = '''      echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---
  # SurfaceFlinger: ekrandaki tum penceri birlestiren goruntu sunucusu.
  # UI olmadan sadece siyah ekran gorunur.
  # bootanimation: acilis ekrani goruntüler.
  # SystemUI, HwLauncher6 APK'laridir; SystemServer/AMS baslatir.
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
  # init.environ.rc de kopyala'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('UI services added successfully')
else:
    print('ERROR: Pattern not found')
    idx = c.find('kopyalandi ve yamalandi')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')