with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove namespace.default.links = /system/bin:/system/lib64" lines
old = 'namespace.default.links = /system/bin:/system/lib64"\n'
count = c.count(old)
if count > 0:
    c = c.replace(old, '')
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet namespace.default.links = /system/bin:/system/lib64" kaldirildi')
else:
    print('namespace.default.links = /system/bin:/system/lib64" bulunamadi')

# Check remaining
import re
remaining = re.findall(r'namespace\.default\.links[^\n]*', c)
if remaining:
    print(f'Kalan namespace.default.links satirlari: {len(remaining)}')
    for m in remaining:
        print(f'  {m.strip()}')
else:
    print('Tum namespace.default.links satirlari temizlendi')
