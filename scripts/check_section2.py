with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# What section is line 3142 in?
print("Lines between 2678 and 3150 (looking for section markers):")
for i in range(2678, min(3150, len(lines))):
    line = lines[i-1].rstrip()
    if any(kw in line for kw in ['cat >', '<<', 'EOF', 'service ', 'onrestart', 'exec >', '# ---', 'init.rc', 'init.environ']):
        print(f'{i}: {line}')

print()
print("Lines 3132-3170:")
for i in range(3132, min(3170, len(lines)) + 1):
    print(f'{i}: {lines[i-1].rstrip()}')
