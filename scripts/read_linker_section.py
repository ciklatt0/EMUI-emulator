with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines[3667:3680], start=3668):
    print(f'{i}: {repr(line)}')