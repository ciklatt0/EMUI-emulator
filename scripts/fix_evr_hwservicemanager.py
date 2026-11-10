with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Comment out start hwservicemanager in initramfs root's init.rc
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
    # start hwservicemanager iptal (SIGABRT ile cokup init'i panike yagirir)
    sed -i 's/^    start hwservicemanager$/    # start hwservicemanager/' "$ROOT/init.rc" 2>/dev/null
    echo "### EVR-L29: init.rc kopyalandi ve yamalandi (initramfs koku) ###"
  fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('start hwservicemanager commented out in initramfs init.rc')
else:
    print('ERROR: Pattern not found')
    idx = c.find('start vold')
    if idx != -1:
        print(f'Found start vold at {idx}: {repr(c[idx-50:idx+150])}')