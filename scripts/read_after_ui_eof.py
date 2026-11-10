with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
idx = content.find('UI_EOF')
if idx != -1:
    print(f"After UI_EOF at {idx}:")
    print(content[idx:idx+800])
