with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

old = 'APEX_OK=0; APEX_FAIL=0\nfor entry in __APEX_LIST__; do'
new = '''# DIKKAT (LIO-AN00/Android 10): init 'wait_for_coldboot_done' bekler ve
# 120 sn sonra InitFatalReboot ile sistem kapatir. coldboot servisi
# QEMU'da calismaz, bu dosya asla olusmaz. Erken olustur.
: > /dev/.coldboot_done 2>/dev/null
m "### /dev/.coldboot_done erken olusturuldu (coldboot timeout'u engellendi) ###"

APEX_OK=0; APEX_FAIL=0
for entry in __APEX_LIST__; do'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('coldboot_done mountapex\'a eklendi')
else:
    print('HATA: APEX_OK=0; APEX_FAIL=0 bulunamadi')
    idx = c.find('APEX_OK=0')
    if idx != -1:
        print(f'Bulunan: {repr(c[idx:idx+30])}')

