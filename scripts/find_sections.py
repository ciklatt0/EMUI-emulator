with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# Find all EOF markers
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.endswith('EOF') or 'EOF' in stripped:
        print(f'{i}: {stripped}')

# Find where /system bind mount is (not linker64)
print()
print("Looking for /system bind mount section:")
for i, line in enumerate(lines, 1):
    if 'mount -o bind /r/system /system' in line:
        print(f'  /system bind mount at line {i}')
    if 'ln -sfn /system/lib64 /lib' in line:
        print(f'  lib symlink at line {i}')
    if 'echo "  init   :' in line:
        print(f'  init echo at line {i}')
