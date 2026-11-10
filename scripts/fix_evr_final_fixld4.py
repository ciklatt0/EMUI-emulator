with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
count = c.count('namespace.default.links = default"')
if count > 0:
    c = c.replace('namespace.default.links = default"', '', count)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet namespace.default.links = default" kaldirildi')
else:
    print('namespace.default.links = default" bulunamadi')

import re
remaining = re.findall(r'namespace\.default\.links[^\n]*', c)
if remaining:
    print(f'Kalan: {len(remaining)}')
    for m in remaining:
        print(f'  {m}')
else:
    print('Tum namespace.default.links temizlendi')
