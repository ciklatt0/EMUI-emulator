with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# 1. Add coldboot_done in mountapex (early-init)
old = 'APEX_OK=0; APEX_FAIL=0\nfor entry in __APEX_LIST__; do'
new = '''# DIKKAT (EVR-L29/Android 10): init coldboot_done bekler, 120 sn sonra kapatir.
: > /dev/.coldboot_done 2>/dev/null
m "### /dev/.coldboot_done erken olusturuldu ###"

APEX_OK=0; APEX_FAIL=0
for entry in __APEX_LIST__; do'''

if old in c:
    c = c.replace(old, new, 1)
    print('coldboot_done mountapex\'a eklendi')
else:
    print('HATA: mountapex baslangici bulunamadi')

# 2. Add coldboot_done in supervisor loop at iter>=1
old2 = '''  pin_selinux
  pin_printk'''

new2 = '''  /system/bin/setprop ro.serialno unknown 2>/dev/null
  # DIKKAT: coldboot_done'u erken olustur
  if [ $n -ge 1 ] && [ ! -e /dev/.coldboot_done ] && [ "${coldboot_done:-0}" = "0" ]; then
    : > /dev/.coldboot_done 2>/dev/null
    coldboot_done=1
    m "### /dev/.coldboot_done olusturuldu ###"
  fi
  pin_selinux
  pin_printk'''

if old2 in c:
    c = c.replace(old2, new2, 1)
    print('coldboot_done supervisor loop\'a eklendi')
else:
    print('HATA: pin_selinux/pin_printk bulunamadi')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('duzenlendi')
