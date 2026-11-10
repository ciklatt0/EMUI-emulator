with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove all namespace.default.links lines (contain path values, invalid)
count = c.count('namespace.default.links')
if count > 0:
    import re
    c = re.sub(r'^[ \t]*namespace\.default\.links[^\n]*\n', '', c, flags=re.MULTILINE)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet namespace.default.links satiri kaldirildi')
else:
    print('namespace.default.links bulunamadi')

# Verify
import re
remaining = re.findall(r'namespace\.default\.links[^\n]*', c)
if remaining:
    print(f'Kalan link satirlari: {len(remaining)}')
    for m in remaining[:5]:
        print(f'  {m[:80]}')
else:
    print('Tum linker links satirlari temizlendi')
