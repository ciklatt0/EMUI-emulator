import sys

with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['bind-mount', 'linker64 overlay', 'zygote', 'app_process', 'system_server', 'SystemServer', 'zygote.*signal', 'zygote.*exited', 'ART', 'ark', 'VM']):
            print(line.rstrip())
