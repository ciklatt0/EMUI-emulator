with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['starting service', 'exited with status', 'linker64', 'bind-mount', 'servicemaker', 'servicemanager', 'zygote', 'system_server', 'surfaceflinger']):
            print(line.rstrip())
