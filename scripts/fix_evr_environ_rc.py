with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# After copying init.environ.rc to initramfs root, add ANDROID_DATA env vars
old = '''  # init.environ.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.environ.rc ]; then
    cp /tmp/sys-mnt-evr/init.environ.rc "$ROOT/init.environ.rc" 2>/dev/null
    echo "### EVR-L29: init.environ.rc kopyalandi initramfs kokuya ###"
  fi'''

new = '''  # init.environ.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.environ.rc ]; then
    cp /tmp/sys-mnt-evr/init.environ.rc "$ROOT/init.environ.rc" 2>/dev/null
    echo "### EVR-L29: init.environ.rc kopyalandi initramfs kokuya ###"
    # ANDROID_DATA ortam degiskenini init.environ.rc'ye ekle (global olarak tum
    # servislere gecer, zygote dahil). init.rc bu dosyayi 'import' eder.
    if ! /bb/grep -q 'ANDROID_DATA' "$ROOT/init.environ.rc" 2>/dev/null; then
      {
        echo ""
        echo "# HARMONY-EMU: Zygote ve diger servisler icin ortam degiskenleri"
        echo "setenv ANDROID_DATA /data"
        echo "setenv ANDROID_ROOT /system"
        echo "setenv ANDROID_STORAGE /data"
      } >> "$ROOT/init.environ.rc" 2>/dev/null
      echo "### EVR-L29: ANDROID_DATA init.environ.rc'ye eklendi ###"
    fi
  fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('ANDROID_DATA added to init.environ.rc')
else:
    print('ERROR: Pattern not found')
    idx = c.find('init.environ.rc de kopyala')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')