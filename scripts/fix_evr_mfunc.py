with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Replace m("...") with /bb/echo "..." in the new code block
old = '''    cp /tmp/sys-mnt-evr/init.zygote64_32.rc "$ROOT/init.zygote64_32.rc" 2>/dev/null
    m "### EVR-L29: init.zygote64_32.rc kopyalandi initramfs kokuya ###"'''

new = '''    cp /tmp/sys-mnt-evr/init.zygote64_32.rc "$ROOT/init.zygote64_32.rc" 2>/dev/null
    /bb/echo "### EVR-L29: init.zygote64_32.rc kopyalandi initramfs kokuya ###"'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('m() replaced with /bb/echo')
else:
    print('Old m() call not found')
    # Debug
    idx = c.find('init.zygote64_32.rc kopyalandi')
    if idx != -1:
        print(f'Found: {repr(c[idx-100:idx+100])}')
