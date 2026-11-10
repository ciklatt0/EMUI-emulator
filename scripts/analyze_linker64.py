with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# Find the linker64 block in the custom /init section (around line 3668)
linker64_start = None
linker64_end = None
for i, line in enumerate(lines):
    if 'Fix linker64 symlink' in line and i > 3600:
        linker64_start = i
    if linker64_start is not None and line.strip() == 'fi' and i > linker64_start:
        linker64_end = i
        break

print(f"Linker64 block in /init: lines {linker64_start+1} to {linker64_end+1}")
if linker64_start is not None:
    for i in range(linker64_start, linker64_end+1):
        print(f"  {i+1}: {lines[i].rstrip()}")

# Find where /system bind mount ends in mountapex (line 3157-3160)
for i in range(3155, 3165):
    if i < len(lines):
        print(f"  {i+1}: {lines[i].rstrip()}")
