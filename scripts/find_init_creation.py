with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    lines = f.readlines()

# Find lines mentioning /init creation
for i, line in enumerate(lines):
    if '/init' in line and ('cp ' in line or 'ln ' in line or 'cat >' in line or 'echo' in line):
        print(f"{i+1}: {line.rstrip()}")