with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Add ro.serialno to init.environ.rc
old = '''    setprop persist.adb.tls_server.enable 0
    # DIKKAT (2026-10-16, L4 3. KOK NEDEN): hw/init.rc'deki zygote'''

new = '''    setprop persist.adb.tls_server.enable 0
    # DIKKAT (EVR-L29/Android 10): ro.serialno prop dosyalarda yok,
    # init bunu genişletemiyor ve 127 ile çıkıyor. Önceden set et.
    setprop ro.serialno unknown
    # DIKKAT (2026-10-16, L4 3. KOK NEDEN): hw/init.rc'deki zygote'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('ro.serialno setprop eklendi')
else:
    print('HATA: metin bulunamadı')
    # Debug
    idx = c.find('setprop persist.adb.tls_server.enable')
    if idx != -1:
        print(f'Bulunan: {repr(c[idx:idx+100])}')
