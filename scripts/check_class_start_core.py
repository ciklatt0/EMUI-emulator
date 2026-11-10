with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
idx = content.find('class_start core')
if idx != -1:
    print(content[max(0,idx-300):idx+300])
else:
    print('Not found')
