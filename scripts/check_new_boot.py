with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['starting service', 'exited with status', 'linker64', 'bind-mount', 'system_server', 'SystemServer', 'zygote', 'surfaceflinger', 'hwcomposer', 'servicemaker', 'servicemanager', 'bootanimation', 'launcher']):
            print(line.rstrip())
