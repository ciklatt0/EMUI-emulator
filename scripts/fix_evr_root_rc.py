with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add root-level rc file copying and patching after init.zygote64_32.rc copy
old = '''  umount /tmp/sys-mnt-evr 2>/dev/null
fi
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali:'''

new = '''  umount /tmp/sys-mnt-evr 2>/dev/null
fi

# EVR-L29: init.rc, ueventd.rc, init.environ.rc system partition root'unda var.
# Init bu dosyalari root seviyesinde arar (/init.rc, /ueventd.rc).
# Initramfs kopyasina kopyalayıp yamalıyoruz (critical kaldirma, exec_start iptal vb).
if [ -f "/root/harmony-build/evr-super-out/parts/system.img" ]; then
  mkdir -p /tmp/sys-mnt-evr 2>/dev/null
  mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img /tmp/sys-mnt-evr 2>/dev/null
  for rcfile in init.rc ueventd.rc; do
    if [ -f /tmp/sys-mnt-evr/$rcfile ]; then
      cp /tmp/sys-mnt-evr/$rcfile "$ROOT/$rcfile" 2>/dev/null
      # critical bayragini kaldir (init paniğini önler)
      sed -i 's/^    critical$/    # critical/' "$ROOT/$rcfile" 2>/dev/null
      sed -i 's/^    shutdown critical$/    # shutdown critical/' "$ROOT/$rcfile" 2>/dev/null
      # exec_start apexd-bootstrap iptal (apexd zaten mountapex ile bagli)
      sed -i 's/^    exec_start apexd-bootstrap$/    # exec_start apexd-bootstrap/' "$ROOT/$rcfile" 2>/dev/null
      # start vold iptal (vold cokuyor, zygote'yi engelliyor)
      sed -i 's/^    start vold$/    # start vold/' "$ROOT/$rcfile" 2>/dev/null
      # exec -- /system/bin/vdc checkpoint iptal
      sed -i 's/^    exec -- \\/system\\/bin\\/vdc/    # exec -- \\/system\\/bin\\/vdc/' "$ROOT/$rcfile" 2>/dev/null
      echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done
  # init.environ.rc de kopyala
  if [ -f /tmp/sys-mnt-evr/init.environ.rc ]; then
    cp /tmp/sys-mnt-evr/init.environ.rc "$ROOT/init.environ.rc" 2>/dev/null
    echo "### EVR-L29: init.environ.rc kopyalandi initramfs kokuya ###"
  fi
  umount /tmp/sys-mnt-evr 2>/dev/null
fi
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali:'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('Root-level rc files added to initramfs with patches')
else:
    print('ERROR: Pattern not found')
    # Debug
    idx = c.find('umount /tmp/sys-mnt-evr')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')