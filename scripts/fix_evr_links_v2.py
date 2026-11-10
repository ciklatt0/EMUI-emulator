with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove namespace.default.links = /system/bin:/system/lib64 echo lines
old = '    echo "namespace.default.links = /system/bin:/system/lib64"\n'

count = c.count(old)
if count > 0:
    c = c.replace(old, '')
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet namespace.default.links echo satiri kaldirildi')
else:
    print('echo satiri bulunamadi')

# Verify
import re
remaining = re.findall(r'echo "namespace\.default\.links[^\n]*', c)
if remaining:
    print(f'Kalan echo link satirlari: {len(remaining)}')
    for m in remaining[:5]:
        print(f'  {m[:80]}')
else:
    print('Tum echo namespace.default.links temizlendi')
