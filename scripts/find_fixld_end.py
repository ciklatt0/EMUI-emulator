with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
# Find fix_ldconfig start
idx = None
for i, line in enumerate(lines):
    if line.strip() == 'fix_ldconfig() {':
        idx = i
        break
if idx != -1:
    print(f"fix_ldconfig starts at line {idx+1}")
    # Find the end - look for '}\n\n# --- printk'
    for j in range(idx, min(idx+200, len(lines))):
        if lines[j].strip() == '}' and j+1 < len(lines) and lines[j+1].strip() == '':
            print(f"Potential end at line {j+1}: {repr(lines[j])}")
            print(f"Next line: {repr(lines[j+1])}")
            print(f"Next+1: {repr(lines[j+2]) if j+2 < len(lines) else 'EOF'}")
            break
