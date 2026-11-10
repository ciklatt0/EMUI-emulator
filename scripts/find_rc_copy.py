with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    for i, line in enumerate(f, 1):
        if 'sys-mnt-evr' in line or 'ROOT/init' in line or 'rcfile' in line or 'init\.zygote' in line:
            print(f"{i}: {line.rstrip()}")