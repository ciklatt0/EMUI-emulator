with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['starting service \'servicemanager\'', 'starting service \'surfaceflinger\'', 'starting service \'vendor.hwcomposer', 'starting service \'vendor.gralloc', 'starting service \'zygote\'', 'servicemanager.*signal', 'surfaceflinger.*signal', 'hwcomposer.*signal', 'gralloc.*signal', 'zygote.*signal']):
            print(line.rstrip())