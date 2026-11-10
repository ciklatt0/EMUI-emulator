with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
pos = 7614
print(content[max(0,pos-100):pos+500])
