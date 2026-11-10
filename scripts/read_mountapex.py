with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()
# Find mountapex script content (between APEX_EOF markers)
in_mountapex = False
for i, line in enumerate(lines, 1):
    if "<<'APEX_EOF'" in line:
        in_mountapex = True
        print(f'{i}: {line.rstrip()}')
        continue
    if in_mountapex and 'APEX_EOF' in line:
        print(f'{i}: {line.rstrip()}')
        break
    if in_mountapex:
        print(f'{i}: {line.rstrip()}')
