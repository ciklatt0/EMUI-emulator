import subprocess
import os

# Find QEMU command from boot script
with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find QEMU command line
for i, line in enumerate(content.split('\n'), 1):
    if 'qemu-system-aarch64' in line:
        print(f'Line {i}: {line.rstrip()}')