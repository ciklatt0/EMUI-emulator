with open('/root/harmony-build/logs/boot-zygote-evr.log', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if 'starting service' in line.lower():
        print(f'Line {i+1}: {line.rstrip()}')
print('---')
print(f'Total lines: {len(lines)}')
print(f'Last line: {lines[-1].rstrip() if lines else "empty"}')
