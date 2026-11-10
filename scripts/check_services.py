with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['starting service \'vendor.hwcomposer', 'starting service \'vendor.gralloc', 'starting service \'surfaceflinger', 'starting service \'servicemanager\'', 'starting service \'zygote\'', 'hwcomposer.*signal', 'gralloc.*signal', 'surfaceflinger.*signal', 'servicemanager.*signal']):
            print(line.rstrip())