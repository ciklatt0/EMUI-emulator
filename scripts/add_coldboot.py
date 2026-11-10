with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# coldboot_done olusturma: supervisor dongusunde, pin_printk sonrasi
# n>=5 oldugunda /dev/.coldboot_done yoksa olustur
old = '''  pin_selinux
  pin_printk'''

new = '''  pin_selinux
  pin_printk
  # DIKKAT (LIO-AN00/Android 10): init 'wait_for_coldboot_done' bekler ama
  # coldboot servisi QEMU'da hicbir zaman bitmiyor (taranacak blok cihazi yok,
  # tumu EROFS). 120 sn sonra init InitFatalReboot ile sistem kapatir ve
  # QEMU -no-reboot ile cikar. C??zum: 5 saniye sonra /dev/.coldboot_done'u
  # elle olusturmak.
  if [ $n -ge 5 ] && [ ! -e /dev/.coldboot_done ] && [ "${coldboot_done:-0}" = "0" ]; then
    mkdir -p /dev 2>/dev/null
    : > /dev/.coldboot_done 2>/dev/null
    coldboot_done=1
    m "### /dev/.coldboot_done olusturuldu (init coldboot beklemesi sonlandirildi) ###"
  fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('coldboot_done eklendi')
else:
    print('HATA: pin_selinux/pin_printk bulunamadi')

