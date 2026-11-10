with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# Check for output redirects in the custom /init section (lines 2960-3686)
for i in range(2959, min(3687, len(lines))):
    line = lines[i].rstrip()
    if 'exec >' in line or 'exec 2>' in line or '>/dev/kmsg' in line or '>/bb/null' in line:
        print(f'{i+1}: {line}')
