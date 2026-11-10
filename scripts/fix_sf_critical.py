with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove critical from surfaceflinger
old = '''service surfaceflinger /system/bin/surfaceflinger
    class core
    user system
    group system graphics drm
    critical
    onrestart restart healthd'''

new = '''service surfaceflinger /system/bin/surfaceflinger
    class core
    user system
    group system graphics drm
    # critical  -- kaldirildi, init paniğini önler
    onrestart restart healthd'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('surfaceflinger critical removed')
else:
    print('Pattern not found')
    idx = c.find('surfaceflinger')
    if idx != -1:
        print(f'Found: {repr(c[idx:idx+200])}')