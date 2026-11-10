with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines[1955:1980], start=1956):
    print(f'{i}: {repr(line)}')