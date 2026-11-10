with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove the hwservicemanager sed line we added
old = """      # start hwservicemanager iptal (SIGABRT ile cokup init'i panike yagirir)
      sed -i 's/^    start hwservicemanager$/    # start hwservicemanager/' "$ROOT/$rcfile" 2>/dev/null
"""
new = ""

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('hwservicemanager sed removed')
else:
    print('ERROR: Pattern not found')
    # Debug
    idx = c.find('hwservicemanager')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+200])}')