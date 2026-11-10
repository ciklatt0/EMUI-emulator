with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Copy init.zygote64_32.rc from system image to initramfs root
old = '''mkdir -p "$ROOT"/{bb,dev,proc,tmp,r,apex,vendor,odm,hw_product,cust,data}
# Android init'in bekledigi mount noktalari (BOS olmali, init doldurur).
# /mnt, /debug_ramdisk, /second_stage_resources yoksa FirstStageMount basarisiz
# olur ve init "Init encountered errors starting first stage" olur.
mkdir -p "$ROOT"/{mnt,debug_ramdisk,second_stage_resources,product,system_ext,postinstall,metadata,storage,cache}'''

new = '''mkdir -p "$ROOT"/{bb,dev,proc,tmp,r,apex,vendor,odm,hw_product,cust,data}
# Android init'in bekledigi mount noktalari (BOS olmali, init doldurur).
# /mnt, /debug_ramdisk, /second_stage_resources yoksa FirstStageMount basarisiz
# olur ve init "Init encountered errors starting first stage" olur.
mkdir -p "$ROOT"/{mnt,debug_ramdisk,second_stage_resources,product,system_ext,postinstall,metadata,storage,cache}
# EVR-L29: init.zygote64_32.rc system partition'inda var, init.rc'de
# import /init.${ro.zygote}.rc olarak referans ediliyor. Init bunu root
# dosya sisteminde arar (/init.zygote64_32.rc), bu yüzden initramfs kokuya
# kopyalamamiz gerekiyor.
if [ -f "/root/harmony-build/evr-super-out/parts/system.img" ]; then
  mkdir -p /tmp/sys-mnt-evr 2>/dev/null
  mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img /tmp/sys-mnt-evr 2>/dev/null
  if [ -f /tmp/sys-mnt-evr/init.zygote64_32.rc ]; then
    cp /tmp/sys-mnt-evr/init.zygote64_32.rc "$ROOT/init.zygote64_32.rc" 2>/dev/null
    m "### EVR-L29: init.zygote64_32.rc kopyalandi initramfs kokuya ###"
  fi
  umount /tmp/sys-mnt-evr 2>/dev/null
fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('init.zygote64_32.rc copy added from system image')
else:
    print('Old mkdir block not found')
    idx = c.find('mkdir -p "$ROOT"/{bb,dev,proc,tmp,r,apex')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')
