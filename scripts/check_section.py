with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# Find what section line 3159 is in - look for nearby section markers
for i in range(3100, 3170):
    if i < len(lines):
        line = lines[i].rstrip()
        if any(kw in line for kw in ['cat >', '<<', 'EOF', 'service ', 'onrestart', 'exec >', 'INIT_EOF', 'APEX_EOF', 'SUPERVISE_EOF', 'RCLLog_EOF']):
            print(f'{i+1}: {line}')

print()
print("Context around line 3159:")
for i in range(3153, 3165):
    if i < len(lines):
        print(f'{i+1}: {lines[i].rstrip()}')
