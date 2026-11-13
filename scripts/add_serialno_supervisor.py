with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# Add ro.serialno setprop at the very start of supervisor loop (before pin_selinux)
old = '''  pin_selinux
  pin_printk'''

new = '''  # DIKKAT (LIO-AN00/Android 10): ro.serialno prop dosyalarda yok,
  # init bunu geni??letemiyor ve 127 ????k???? kodu ile sonlan??yor.
  # Erken set et ki '${ro.serialno}' i??eren komutlar ??al????abilsin.
  /system/bin/setprop ro.serialno unknown 2>/dev/null
  pin_selinux
  pin_printk'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('ro.serialno setprop supervisor baslangic??na eklendi')
else:
    print('HATA: pin_selinux/pin_printk bulunamad??')

