with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add start hwservicemanager comment after start vold line in rc file patching
old = "      # start vold iptal (vold cokuyor, zygote'yi engelliyor)\n      sed -i 's/^    start vold$/    # start vold/' \"$ROOT/$rcfile\" 2>/dev/null"
new = old + "\n      # start hwservicemanager iptal (SIGABRT ile cokup init'i panike yagirir)\n      sed -i 's/^    start hwservicemanager$/    # start hwservicemanager/' \"$ROOT/$rcfile\" 2>/dev/null"

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('start hwservicemanager commented out in rc file patching')
else:
    print('ERROR: Pattern not found')
    # Debug
    idx = c.find('# start vold iptal')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')