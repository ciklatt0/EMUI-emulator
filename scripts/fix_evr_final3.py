with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()

# Find the line with "ADIM 1: rc agacini kopyala"
idx = None
for i, line in enumerate(lines):
    if 'ADIM 1: rc agacini kopyala' in line:
        idx = i
        break

if idx is not None:
    print(f"Found ADIM 1 at line {idx+1}")
    # Print surrounding lines
    for j in range(max(0, idx-2), min(len(lines), idx+10)):
        print(f"  {j+1}: {repr(lines[j])}")
else:
    print("ADIM 1 not found")
