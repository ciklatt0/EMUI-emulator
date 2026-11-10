with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()
    # Show last 50 lines
    for line in lines[-50:]:
        print(line.rstrip())