with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# 1. Baslangic config'te namespace.default.links'i kaldir
old1 = '''      /bb/echo "namespace.default.links = system"
    } > "$CFG" 2>/bb/null'''

new1 = '''    } > "$CFG" 2>/bb/null'''

if old1 in c:
    c = c.replace(old1, new1, 1)
    print('baslangic config links kaldirildi')
else:
    print('HATA: baslangic config links bulunamadi')

# 2. Vendor bolumundeki link'i kaldir
old2 = '''    /bb/echo "namespace.default.links = system"; \\
    } > /tmp/ld.marked 2>/bb/null'''

new2 = '''    } > /tmp/ld.marked 2>/bb/null'''

if old2 in c:
    c = c.replace(old2, new2, 1)
    print('vendor link kaldirildi')
else:
    print('HATA: vendor link bulunamadi')
    import re
    matches = re.findall(r'namespace\.default\.links[^\n]*', c)
    for m in matches:
        print(f'  Bulunan link: {m}')

with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')

