with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()

# Print lines around hwcomposer crash at 104s
for i, line in enumerate(lines):
    if 'vendor.hwcomposer-2-2' in line and '104.' in line:
        start = max(0, i-10)
        end = min(len(lines), i+5)
        for j in range(start, end):
            print(lines[j].rstrip())
        print("="*60)
        break