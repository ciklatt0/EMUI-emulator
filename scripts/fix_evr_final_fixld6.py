with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove remaining namespace.default.links = system"
old = 'namespace.default.links = system"\n'
count = c.count(old)
if count > 0:
    c = c.replace(old, '')
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet namespace.default.links = system" kaldirildi')
else:
    print('Bulunamadi')

import re
remaining = re.findall(r'namespace\.default\.links[^\n]*', c)
if remaining:
    print(f'Kalan: {len(remaining)}')
    for m in remaining:
        print(f'  {m.strip()}')
else:
    print('Temizlendi')
