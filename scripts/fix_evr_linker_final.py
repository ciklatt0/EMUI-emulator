with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Remove link.default/link.public (invalid properties - bionic rejects them)
old1 = '''  : > /tmp/ld.link
  /bb/echo "link.default = default,system${APEXNS:+,$APEXNS}" >> /tmp/ld.link
  [ -n "$APEXNS" ] && /bb/echo "link.public = $APEXNS" >> /tmp/ld.link
  m "### link.default/public: $NSOK namespace baglandi ($NSNO tanimsiz atlandi) ###"
  /bb/cat /tmp/ld.link /tmp/ld.new > /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

new1 = '''  # link.default / link.public gecersiz ozellikler, atlaniyor
  # Namespace baglantilari [system] ve [vendor] bolumlerindeki
  # namespace.default.links ile zaten handle ediliyor.
  m "### link.default/public: atlandi (gecersiz ozellik) ###"
  /bb/cp /tmp/ld.new /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

if old1 in c:
    c = c.replace(old1, new1, 1)
    print('link.default/public kaldirildi')
else:
    print('HATA: link.default bloğu bulunamadı')
    import re
    matches = re.findall(r'link\.default[^\n]*', c)
    for m in matches[:3]:
        print(f'  Bulunan: {m[:100]}')

# Fix 2: Remove namespace.default.links = system from vendor block
old2 = '''    /bb/echo "namespace.default.links = system"; \\
    } > /tmp/ld.marked 2>/bb/null'''

new2 = '''    } > /tmp/ld.marked 2>/bb/null'''

if old2 in c:
    c = c.replace(old2, new2, 1)
    print('vendor link kaldirildi')
else:
    print('HATA: vendor link bulunamadı')
    import re
    matches = re.findall(r'namespace\.default\.links[^\n]*', c)
    for m in matches[:5]:
        print(f'  Bulunan link: {m[:80]}')

# Fix 3: Add sed cleanup for all namespace.default.links lines
old3 = '''  NAP=$(/bb/grep -c "^apex\\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new'''

new3 = '''  NAP=$(/bb/grep -c "^apex\\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new
  # DIKKAT (EVR-L29/Android 10): tum namespace.default.links satirlarini kaldir.
  # isolated = false oldugu icin explicit links gerekmemeli. Path'ler
  # (orn. /system/bin:/system/lib64) gecersiz namespace referansi olusturur.
  /bb/sed -i '/^namespace\\.default\\.links/d' /tmp/ld.new 2>/dev/null'''

if old3 in c:
    c = c.replace(old3, new3, 1)
    print('links temizleme adimi eklendi')
else:
    print('HATA: NAP bloğu bulunamadı')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')
