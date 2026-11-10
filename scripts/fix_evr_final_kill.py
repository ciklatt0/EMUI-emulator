with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find and comment out the problematic awk block in rclog
# Find the line with /^[ \t]*wait_for_prop[ \t]+apexd\.status[ \t]+activated[ \t]*$/ {
old = '''  /^[ \t]*wait_for_prop[ \t]+apexd\.status[ \t]+activated[ \t]*$/ {
    print "    setprop apexd.status activated  # RCYAMALAMA: bekleme yerine elle" > out
    nap++; next
  }
  awk program liner'''

# Actually let's just find the exact line and comment it out
lines = c.split('\n')
for i, line in enumerate(lines):
    if 'awk -v OVL="$OVL" -v SRC="$SRC" -v ZYG="$RO_ZYG" -v HW="$RO_HW"' in line:
        print(f"Found awk call at line {i+1}: {line.strip()}")
        # Show surrounding lines
        for j in range(max(0, i-3), min(len(lines), i+5)):
            print(f"  {j+1}: {lines[j].rstrip()}")
        break
