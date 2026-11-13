with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# link.default / link.public satirlarini kaldir (gecersiz ozellikler)
old = '''  : > /tmp/ld.link
  /bb/echo "link.default = default,system${APEXNS:+,$APEXNS}" >> /tmp/ld.link
  [ -n "$APEXNS" ] && /bb/echo "link.public = $APEXNS" >> /tmp/ld.link
  m "### link.default/public: $NSOK namespace baglandi ($NSNO tanimsiz atlandi) ###"
  /bb/cat /tmp/ld.link /tmp/ld.new > /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

new = '''  # link.default / link.public gecersiz ozellikler, atlaniyor
  # Namespace baglantilari [system] ve [vendor] bolumlerindeki
  # namespace.default.links ile zaten handle ediliyor.
  m "### link.default/public: atlandi (gecersiz ozellik) ###"
  /bb/cp /tmp/ld.new /tmp/ld.new2
  /bb/mv /tmp/ld.new2 /tmp/ld.new'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('link.default/public kaldirildi')
else:
    print('HATA: link.default blo??u bulunamadi')
    # Debug
    import re
    matches = re.findall(r'link\.default[^\n]*', c)
    for m in matches:
        print(f'  Bulunan: {m[:100]}')

