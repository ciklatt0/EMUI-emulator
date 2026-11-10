with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
idx = content.find('UI_EOF')
if idx != -1:
    print(f"UI_EOF at {idx}:")
    print(content[max(0,idx-200):idx+500])
