with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()
    for line in lines:
        if any(kw in line for kw in ['starting service', 'starting service \'system_server\'', 'starting service \'SurfaceFlinger\'', 'starting service \'launcher\'', 'starting service \'zygote\'']):
            print(line.rstrip())