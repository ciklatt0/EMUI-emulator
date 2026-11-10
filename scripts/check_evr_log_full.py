with open('/root/harmony-build/logs/boot-zygote-evr.log', 'r') as f:
    lines = f.readlines()
# Show everything from init second stage to crash
started = False
for i, line in enumerate(lines):
    if 'init second stage started' in line:
        started = True
    if started:
        print(line.rstrip())
