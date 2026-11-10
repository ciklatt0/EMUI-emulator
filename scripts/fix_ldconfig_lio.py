import re

with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# fix_ldconfig'de [ -f "$CFG" ] || return 0 satirini bul ve degistir
# Dosya yoksa sifirdan bir config olustur
old = '''  [ -f "$CFG" ] || return 0
  # ---------------------------------------------------------------------'''

new = '''  # DIKKAT (LIO-AN00/Android 10): linkerconfig binary YOK (Android 10'da
  # henuz yok, Android 11+'de geldi). Bu yuzden ld.config.txt olusmamis
  # olabilir. Dosya yoksa sifirdan olustur.
  if [ ! -f "$CFG" ]; then
    mkdir -p /linkerconfig 2>/bb/null
    {
      /bb/echo "dir.system = /system/bin/"
      /bb/echo "dir.system = /system/lib64/"
      /bb/echo "dir.vendor = /vendor/bin/"
      /bb/echo "dir.vendor = /vendor/lib64/"
      /bb/echo ""
      /bb/echo "[system]"
      /bb/echo "namespace.default.isolated = false"
      /bb/echo "namespace.default.visible = true"
      /bb/echo "namespace.default.search.paths = /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
      /bb/echo "namespace.default.permitted.paths = /system/bin:/system/lib64:/vendor/bin:/vendor/lib64"
      /bb/echo "namespace.default.links = default,system"
      /bb/echo ""
      /bb/echo "[vendor]"
      /bb/echo "namespace.default.isolated = false"
      /bb/echo "namespace.default.visible = true"
      /bb/echo "namespace.default.search.paths = /vendor/bin:/vendor/lib64:/system/bin:/system/lib64"
      /bb/echo "namespace.default.permitted.paths = /vendor/bin:/vendor/lib64:/system/bin:/system/lib64"
      /bb/echo "namespace.default.links = default,system"
    } > "$CFG" 2>/bb/null
    /bb/echo "### ld.config.txt: linkerconfig yok, sifirdan olusturuldu ###"
  fi
  [ -f "$CFG" ] || return 0
  # ---------------------------------------------------------------------'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'w') as f:
        f.write(c)
    print('fix_ldconfig duzenlendi')
else:
    print('HATA: eski kod bulunamadi')
    # Debug: ara dizeleri ara
    if '[ -f "$CFG" ] || return 0' in c:
        print('  [ -f "$CFG" ] found but context different')
    else:
        print('  [ -f "$CFG" ] NOT FOUND')

