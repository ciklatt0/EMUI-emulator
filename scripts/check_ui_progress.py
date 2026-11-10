with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['starting service \'zygote\'', 'starting service \'system_server\'', 'starting service \'surfaceflinger\'', 'starting service \'servicemanager\'', 'starting service \'vendor.hwcomposer', 'starting service \'bootanimation\'', 'starting service \'launcher\'', 'starting service \'HwLauncher6\'']):
            print(line.rstrip())