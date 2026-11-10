with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
for i in range(5687, 5710):
    if i < len(lines):
        print(f'{i+1}: {repr(lines[i])}')
