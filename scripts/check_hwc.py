with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if 'hwcomposer' in line.lower() or 'composer' in line.lower():
            print(line.rstrip())