with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    count = 0
    for line in f:
        if 'surfaceflinger' in line.lower():
            print(line.rstrip())
            count += 1
            if count >= 30:
                break