with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()
idx = c.find('APEX mount (init')
if idx != -1:
    print(repr(c[idx:idx+200]))
else:
    print('not found')
    # Try finding mountapex echo
    idx2 = c.find('/bb/echo "--- APEX')
    if idx2 != -1:
        print(repr(c[idx2:idx2+100]))
    else:
        print('/bb/echo --- APEX not found')

