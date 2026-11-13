with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# coldboot_done'u erken olustur (iter=1 yerine iter=5)
old = '''  if [ $n -ge 5 ] && [ ! -e /dev/.coldboot_done ] && [ "${coldboot_done:-0}" = "0" ]; then'''

new = '''  if [ $n -ge 1 ] && [ ! -e /dev/.coldboot_done ] && [ "${coldboot_done:-0}" = "0" ]; then'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('coldboot_done esigi iter=5 -> iter=1 cekildi')
else:
    print('HATA: coldboot_done kosulu bulunamadi')

