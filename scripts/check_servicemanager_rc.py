with open('/root/harmony-build/initramfs-boot/init.rc') as f:
    for i, line in enumerate(f, 1):
        if 'servicemanager' in line:
            print(f"{i}: {line.rstrip()}")