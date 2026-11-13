with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# Kalan default,system link'i duzel
old = 'namespace.default.links = default,system'
new = 'namespace.default.links = system'

count = c.count(old)
if count > 0:
    c = c.replace(old, new)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print(f'{count} adet default,system link duzeltilmis -> system')
else:
    print('default,system link bulunamadi')

# Devami: visible satirinin diger kopya'si var mi?
old2 = 'namespace.default.visible = true'
count2 = c.count(old2)
if count2 > 0:
    c = c.replace(old2, '')
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print(f'{count2} adet visible satir kaldirildi')
else:
    print('visible satir bulunamadi')

