with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines, 1):
    if 'linker64' in line or 'Fix linker64' in line:
        print(f'{i}: {repr(line)}')