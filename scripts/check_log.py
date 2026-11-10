import sys

with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['bind-mount', 'linker64', 'system-bin-tmp', 'overlay', 'servicemanager exited', 'status 255', 'system_server', 'SurfaceFlinger']):
            print(line.rstrip())
