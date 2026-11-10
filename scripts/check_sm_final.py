with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()
    for line in lines:
        if any(kw in line.lower() for kw in ['servicemanager', 'linker64', 'exited with status', 'starting service']):
            print(line.rstrip())