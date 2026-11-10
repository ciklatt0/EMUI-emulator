with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# mountapex'te coldboot_done olusturma (early-init, init beklemeye baslamadan once)
old = '''  /bb/echo "--- APEX mount (init early-init) ---"

APEX_OK=0; APEX_FAIL=0'''

new = '''  /bb/echo "--- APEX mount (init early-init) ---"

# DIKKAT (LIO-AN00/Android 10): init 'wait_for_coldboot_done' bekler ve
# 120 sn sonra InitFatalReboot ile sistem kapatir. coldboot servisi
# QEMU'da calismaz, bu dosya asla olusmaz. Erken olustur.
: > /dev/.coldboot_done 2>/dev/null
m "### /dev/.coldboot_done erken olusturuldu (coldboot timeout'u engellendi) ###"

APEX_OK=0; APEX_FAIL=0'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('coldboot_done mountapex\'a eklendi')
else:
    print('HATA: mountapex baslangici bulunamadi')

