with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
idx = c.find('propof()')
if idx != -1:
    print(c[idx:idx+800])
print('---')
idx2 = c.find('RO_ZYG=$(propof')
if idx2 != -1:
    print(c[idx2:idx2+300])
print('---')
idx3 = c.find('awk -v OVL')
if idx3 != -1:
    print(c[idx3:idx3+300])

