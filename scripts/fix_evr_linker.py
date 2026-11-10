with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: linker config - remove link.default/public (invalid property)
old = '''  : > /tmp/ld.link
  /bb/echo "link.default = default,system${APEXNS:+,$APEXNS}" >> /tmp/ld.link
  [ -n "$APEXNS" ] && /bb/echo "link.public = $APEXNS" >> /tmp/ld.link
  m "### link.default/public: $NSOK namespace baglandi ($NSNO tanimsiz atlandi) ###"
  /bb/cat /tmp/ld.link /tmp/ld.new > /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

new = '''  # link.default / link.public gecersiz ozellikler, atlaniyor
  m "### link.default/public: atlandi (gecersiz ozellik) ###"
  /bb/cp /tmp/ld.new /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

if old in c:
    c = c.replace(old, new, 1)
    print('link.default kaldirildi')
else:
    print('HATA: link.default bloğu bulunamadi')

# Fix 2: Remove namespace.default.links = system (invalid namespace reference)
count_links = c.count('namespace.default.links = system')
if count_links > 0:
    c = c.replace('namespace.default.links = system', '')
    print(f'{count_links} adet namespace.default.links = system kaldirildi')
else:
    print('namespace.default.links = system bulunamadi')

# Fix 3: Add sed to remove all namespace.default.links lines before writing config
old3 = '''  NAP=$(/bb/grep -c "^apex\\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new'''

new3 = '''  NAP=$(/bb/grep -c "^apex\\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new
  # DIKKAT (EVR-L29/Android 10): tum namespace.default.links satirlarini kaldir.
  /bb/sed -i '/^namespace\\.default\\.links/d' /tmp/ld.new 2>/dev/null'''

if old3 in c:
    c = c.replace(old3, new3, 1)
    print('links temizleme adimi eklendi')
else:
    print('HATA: NAP bloğu bulunamadi')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('duzenlendi')
