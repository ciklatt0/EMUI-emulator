with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if line.strip().startswith('m()') or line.strip().startswith('m ()'):
        print(f"Line {i+1}: {line.rstrip()}")
        # Print next 10 lines
        for j in range(i+1, min(i+12, len(lines))):
            print(f"  {j+1}: {lines[j].rstrip()}")
        break
