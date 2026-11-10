with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# 1. Init.environ.rc'teki baslangic config'indeki link satirini d??zelt
old1 = '''      /bb/echo "namespace.default.links = default,system"
    } > "$CFG" 2>/bb/null'''

new1 = '''      /bb/echo "namespace.default.links = system"
    } > "$CFG" 2>/bb/null'''

if old1 in c:
    c = c.replace(old1, new1, 1)
    print('baslangic config link duzeltildi')
else:
    print('HATA: baslangic config link bulunamadi')

# 2. [vendor] bolumundeki link satirini duzel
old2 = '''    /bb/echo "namespace.default.links = default,system"; \\
    } > /tmp/ld.marked 2>/bb/null'''

new2 = '''    /bb/echo "namespace.default.links = system"; \\
    } > /tmp/ld.marked 2>/bb/null'''

if old2 in c:
    c = c.replace(old2, new2, 1)
    print('vendor link duzeltildi')
else:
    print('HATA: vendor link bulunamadi')
    # Debug
    import re
    matches = re.findall(r'namespace\.default\.links[^\n]*', c)
    for m in matches:
        print(f'  Bulunan link: {m}')

# 3. visible satirini kaldir (gecersiz ozellik)
old3 = '''    /bb/echo "namespace.default.visible = true"; \\
    /bb/echo "namespace.default.search.paths = $VPATHS"; \\'''

new3 = '''    /bb/echo "namespace.default.search.paths = $VPATHS"; \\'''

if old3 in c:
    c = c.replace(old3, new3, 1)
    print('visible satir kaldirildi')
else:
    print('HATA: visible satir bulunamadi')

with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')

