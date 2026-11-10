with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

old = '''mkdir -p "$ROOT"/{mnt,debug_ramdisk,second_stage_resources,product,system_ext,postinstall,metadata,storage,cache}
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali: init birinci
# asamada sysfs'i kendisi mount ediyor. Dizin yoksa "No such file or
# directory"; biz mount edersek "Device or resource busy".
mkdir -p "$ROOT/sys/fs/selinux"'''

new = '''mkdir -p "$ROOT"/{mnt,debug_ramdisk,second_stage_resources,product,system_ext,postinstall,metadata,storage,cache}
# Android init'in bekledigi mount noktalari (BOS olmali, init doldurur).
# /mnt, /debug_ramdisk, /second_stage_resources yoksa FirstStageMount basarisiz
# olur ve init "Init encountered errors starting first stage" olur.
mkdir -p "$ROOT"/{mnt,debug_ramdisk,second_stage_resources,product,system_ext,postinstall,metadata,storage,cache}
# EVR-L29: init.zygote64_32.rc system partition'inda var, init.rc'de
# import /init.${ro.zygote}.rc olarak referans ediliyor. Init bunu root
# dosya sisteminde arar (/init.zygote64_32.rc), bu yuzden initramfs kokuya
# kopyalamamiz gerekiyor.
if [ -f "/root/harmony-build/evr-super-out/parts/system.img" ]; then
  mkdir -p /tmp/sys-mnt-evr 2>/dev/null
  mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img /tmp/sys-mnt-evr 2>/dev/null
  if [ -f /tmp/sys-mnt-evr/init.zygote64_32.rc ]; then
    cp /tmp/sys-mnt-evr/init.zygote64_32.rc "$ROOT/init.zygote64_32.rc" 2>/dev/null
    m "### EVR-L29: init.zygote64_32.rc kopyalandi initramfs kokuya ###"
  fi
  umount /tmp/sys-mnt-evr 2>/dev/null
fi
# /sys ve /sys/fs/selinux VAR OLMALI ama MOUNT EDILMEMIS olmali: init birinci
# asamada sysfs'i kendisi mount ediyor. Dizin yoksa "No such file or
# directory"; biz mount edersek "Device or resource busy".
mkdir -p "$ROOT/sys/fs/selinux"'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('init.zygote64_32.rc copy added')
else:
    print('Old block not found')
    idx = c.find('mkdir -p "$ROOT"/{mnt,debug_ramdisk')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')
