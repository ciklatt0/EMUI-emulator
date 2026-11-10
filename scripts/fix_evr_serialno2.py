with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
old = 'KCMD="console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"'
new = 'KCMD="console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true androidboot.serialno=unknown printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"'
if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('KCMD updated with androidboot.serialno=unknown')
else:
    print('KCMD pattern not found')
    idx = c.find('KCMD=')
    if idx != -1:
        print(repr(c[idx:idx+200]))
