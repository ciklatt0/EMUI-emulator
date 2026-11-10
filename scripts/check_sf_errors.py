with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()

# Print lines around first surfaceflinger start (115s)
for i, line in enumerate(lines):
    if 'starting service \'surfaceflinger\'' in line and '115.' in line:
        # Print 20 lines before and after
        start = max(0, i-15)
        end = min(len(lines), i+15)
        for j in range(start, end):
            print(lines[j].rstrip())
        print("="*60)
        break