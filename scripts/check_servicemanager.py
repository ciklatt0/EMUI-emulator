with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    for line in f:
        if any(kw in line for kw in ['servicemanager', 'linker64', 'linker-config', 'fix_ldconfig']):
            print(line.rstrip())