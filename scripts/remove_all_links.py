with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# TUM namespace.default.links = system occurrences'i kaldir
count = c.count('namespace.default.links = system')
if count > 0:
    c = c.replace('namespace.default.links = system', '')
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet namespace.default.links = system kaldirildi')
else:
    print('Bulunamadi')

# Kaldi mi?
import re
remaining = re.findall(r'namespace\.default\.links[^\n]*', c)
if remaining:
    print(f'Kalan link satirlari: {len(remaining)}')
    for m in remaining[:5]:
        print(f'  {m[:80]}')
else:
    print('Tum linker links satirlari temizlendi')

