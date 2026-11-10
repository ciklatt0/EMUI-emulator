with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Remove link.default/public section
old1 = '''  : > /tmp/ld.link
  /bb/echo "link.default = default,system${APEXNS:+,$APEXNS}" >> /tmp/ld.link
  [ -n "$APEXNS" ] && /bb/echo "link.public = $APEXNS" >> /tmp/ld.link
  m "### link.default/public: $NSOK namespace baglandi ($NSNO tanimsiz atlandi) ###"
  /bb/cat /tmp/ld.link /tmp/ld.new > /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

new1 = '''  # link.default / link.public gecersiz ozellikler, atlaniyor
  m "### link.default/public: atlandi (gecersiz ozellik) ###"
  /bb/cp /tmp/ld.new /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

if old1 in c:
    c = c.replace(old1, new1, 1)
    print('link.default/public kaldirildi')
else:
    print('HATA: link.default bloğu bulunamadı')

# Fix 2: Remove all namespace.default.links echo lines  
import re
# Count before
before = len(re.findall(r'echo "namespace\.default\.links[^\n]*', c))
c = re.sub(r'^[ \t]*echo "namespace\.default\.links[^\n]*\n', '', c, flags=re.MULTILINE)
after = len(re.findall(r'echo "namespace\.default\.links[^\n]*', c))
print(f'{before - after} adet namespace.default.links echo kaldirildi')

# Fix 3: Add sed cleanup for all namespace.default.links lines before writing config
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
    print('sed cleanup eklendi')
else:
    print('HATA: NAP bloğu bulunamadı')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')
