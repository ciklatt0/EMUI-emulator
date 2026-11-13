with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
idx = c.find('APEX mount')
if idx != -1:
    print(repr(c[idx-50:idx+100]))
else:
    print('APEX mount not found')

