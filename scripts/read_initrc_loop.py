with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
pos = content.find('for rcfile in init.rc ueventd.rc')
if pos != -1:
    print(content[pos:pos+1500])
