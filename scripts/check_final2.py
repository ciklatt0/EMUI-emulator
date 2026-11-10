with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()
    for i, line in enumerate(lines):
        if any(kw in line for kw in ['starting service', 'system_server', 'SurfaceFlinger', 'bootanimation', 'zygote']):
            print(line.rstrip())