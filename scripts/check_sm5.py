import sys
with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if 'servicemanager' in line.lower() or 'linker64' in line.lower():
            print(line.rstrip())