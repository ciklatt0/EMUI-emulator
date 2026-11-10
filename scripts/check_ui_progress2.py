with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if 'starting service' in line and any(kw in line for kw in ['zygote', 'system_server', 'surfaceflinger', 'servicemanager', 'hwcomposer', 'bootanimation', 'launcher']):
            print(line.rstrip())