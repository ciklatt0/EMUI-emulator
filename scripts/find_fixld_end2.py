with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
# Find fix_ldconfig start
for i, line in enumerate(lines):
    if line.strip() == 'fix_ldconfig() {':
        start = i
        break
# Print from start to start+150
for j in range(start, min(start+200, len(lines))):
    print(f"{j+1}: {lines[j].rstrip()}")
