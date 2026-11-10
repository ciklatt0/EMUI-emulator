with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find fix_ldconfig function and replace it entirely
old_start = 'fix_ldconfig() {'
old_end = '  return 0\n}\n\n# --- printk susturmayi kapat ----------------'

idx_start = c.find(old_start)
idx_end = c.find(old_end, idx_start)

if idx_start != -1 and idx_end != -1:
    idx_end += len(old_end)
    
    new_func = '''fix_ldconfig() {
  CFG=/linkerconfig/ld.config.txt
  [ -d /apex/com.android.runtime ] || return 0
  # DIKKAT (EVR-L29): her turda konfigurasyonu sifirdan olustur.
  # init'in linkerconfig'i dosyayi bozabilir, bu yüzden her turda
  # yeniden yazmak en guvenlidir.
  mkdir -p /linkerconfig 2>/bb/null
  {
    /bb/echo "# HARMONY-EMU apex yollari basliyor"
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
    for a in /apex/*/; do
      [ -d "$a/lib64" ] || continue
      lname=${a#/apex/}; case "$lname" in */) lname=${lname%/} ;; esac
      /bb/echo "namespace.default.search.paths += /apex/$lname/lib64"
      /bb/echo "namespace.default.permitted.paths += /apex/$lname/lib64"
      if [ -d "$a/lib64/bionic" ]; then
        /bb/echo "namespace.default.search.paths += /apex/$lname/lib64/bionic"
        /bb/echo "namespace.default.permitted.paths += /apex/$lname/lib64/bionic"
      fi
    done
  } > "$CFG" 2>/bb/null
  m "### ld.config.txt sifirdan olusturuldu ###"
  ld_ok=1
}

# --- printk susturmayi kapat ----------------'''

    c = c[:idx_start] + new_func + c[idx_end:]
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('fix_ldconfig replaced with simple version')
else:
    print('Could not find fix_ldconfig function boundaries')
    idx = c.find('fix_ldconfig() {')
    if idx != -1:
        print(f'Found fix_ldconfig at {idx}')
        print(repr(c[idx:idx+200]))
