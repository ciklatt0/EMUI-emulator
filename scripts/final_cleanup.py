with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# fix_ldconfig'in sonuna, tum namespace.default.links satirlarini kaldiran bir adim ekle
old = '''  NAP=$(/bb/grep -c "^apex\\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new'''

new = '''  NAP=$(/bb/grep -c "^apex\\." /tmp/ld.apex 2>/dev/null)
  [ "${NAP:-0}" -gt 0 ] && m "### [apex] bolumu: $NAP APEX eslemessi ###"
  /bb/cat /tmp/ld.apex >> /tmp/ld.new
  # DIKKAT (LIO-AN00/Android 10): tum namespace.default.links satirlarini kaldir.
  # isolated = false oldugu icin explicit links gerekmemeli. Path'ler
  # (orn. /system/bin:/system/lib64) gecersiz namespace referansi olusturur.
  /bb/sed -i '/^namespace\\.default\\.links/d' /tmp/ld.new 2>/dev/null'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('links temizleme adimi eklendi')
else:
    print('HATA: hedef bulunamadi')

