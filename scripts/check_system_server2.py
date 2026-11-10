with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['starting service', 'exited with status', 'system_server', 'SystemServer', 'zygote', 'surfaceflinger', 'hwcomposer', 'servicemanager', 'bootanimation']):
            print(line.rstrip())
