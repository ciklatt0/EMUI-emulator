with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
# Find propof function body
idx = c.find('propof()')
if idx != -1:
    # Find 'return 1' after propof start
    idx3 = c.find('return 1', idx)
    if idx3 != -1:
        print(repr(c[idx:idx3+20]))
    else:
        print('return 1 not found after propof')
else:
    print('propof() not found')

