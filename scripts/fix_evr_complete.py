with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Force ro.zygote=zygote64_32 regardless of what propof returns
old = '''RO_ZYG=$(propof ro.zygote)
RO_HW=$(propof ro.hardware)
RO_SR=$(propof ro.serialno)'''
new = '''RO_ZYG=$(propof ro.zygote)
# DIKKAT (EVR-L29): ro.zygote prop dosyalarda yok, androidboot.zygote
# kernel komut satirindan geliyor ama propof() dosyalardan okur.
# Hardcode edelim:
RO_ZYG="zygote64_32"
RO_HW=$(propof ro.hardware)
RO_SR=$(propof ro.serialno)'''

if old in c:
    c = c.replace(old, new, 1)
    print('RO_ZYG hardcoded to zygote64_32')
else:
    print('RO_ZYG block not found')

# Fix 2: After fix_ldconfig generates (or fails to generate) ld.config.txt,
# add a simple fallback that creates a minimal config with APEX paths
# This runs AFTER fix_ldconfig, so our config is the final one
old2 = '''  return 0
}

# --- printk susturmayi kapat ----------------'''
new2 = '''  return 0
}

# --- EVR-L29: Linker config emin olabilmek icin son kez dogrula ----------
# fix_ldconfig calistiktan sonra, /linkerconfig/ld.config.txt'in
# APEX yollarini içerdiğinden emin ol. Eger yoksa, sifirdan olustur.
ensure_ldconfig_final() {
  CFG=/linkerconfig/ld.config.txt
  [ -f "$CFG" ] || return 0
  # APEX yolu var mi kontrol et
  if ! /bb/grep -q '/apex/' "$CFG" 2>/bb/null; then
    m "### ld.config.txt'de APEX yolu yok; sifirdan uretiliyor ###"
    mkdir -p /linkerconfig 2>/bb/null
    {
      /bb/echo "# HARMONY-EMU final config"
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
      /bb/echo "namespace.default.links = system"
      for entry in __APEX_LIST__; do
        apname=${entry##*:}
        /bb/echo "namespace.default.search.paths += /apex/$apname/lib64"
        /bb/echo "namespace.default.permitted.paths += /apex/$apname/lib64"
        if [ -d "/apex/$apname/lib64/bionic" ]; then
          /bb/echo "namespace.default.search.paths += /apex/$apname/lib64/bionic"
          /bb/echo "namespace.default.permitted.paths += /apex/$apname/lib64/bionic"
        fi
      done
    } > "$CFG" 2>/bb/null
    m "### ld.config.txt son definitif versiyon yazildi ###"
  fi
}

# --- printk susturmayi kapat ----------------'''

if old2 in c:
    c = c.replace(old2, new2, 1)
    print('ensure_ldconfig_final added')
else:
    print('Old fix_ldconfig end block not found')
    # Debug
    idx = c.find('# --- printk susturmayi kapat')
    if idx != -1:
        print(f'Found printk section at {idx}')

# Fix 3: Call ensure_ldconfig_final in the supervisor loop, after ensure_apex
old3 = '''  [ "$SUPERVISE_APEX" = "1" ] && ensure_apex
  [ "$n" -eq 60 ] && m "### iter=60 -> apex bitti"'''
new3 = '''  [ "$SUPERVISE_APEX" = "1" ] && ensure_apex
  ensure_ldconfig_final
  [ "$n" -eq 60 ] && m "### iter=60 -> apex bitti"'''

if old3 in c:
    c = c.replace(old3, new3, 1)
    print('ensure_ldconfig_final called in supervisor loop')
else:
    print('Supervisor loop call site not found')
    idx = c.find('[ "$SUPERVISE_APEX" = "1" ] && ensure_apex')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+100])}')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('dosya yazildi')
