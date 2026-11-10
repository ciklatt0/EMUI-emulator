with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

old = 'RO_ZYG=$(propof ro.zygote)'
new = '''# DIKKAT (EVR-L29): ro.zygote prop dosyalarda yok, androidboot.zygote
# kernel komut satirindan geliyor ama propof() dosyalardan okur.
# Hardcode edelim:
RO_ZYG="zygote64_32"'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('RO_ZYG hardcoded to zygote64_32')
else:
    print('RO_ZYG=$(propof ro.zygote) not found')
    idx = c.find('RO_ZYG=')
    if idx != -1:
        print(f'Found: {repr(c[idx:idx+60])}')
