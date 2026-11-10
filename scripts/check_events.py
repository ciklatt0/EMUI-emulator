import sys

with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()
    
# Show all key service events
for i, line in enumerate(lines):
    if any(kw in line for kw in ['starting service', 'exited with status', 'socket']):
        if any(kw2 in line for kw2 in ['servicemanager', 'zygote', 'system_server', 'surfaceflinger', 'hwcomposer', 'bootanimation', 'launcher', 'bind-mount', 'linker64']):
            print(line.rstrip())
