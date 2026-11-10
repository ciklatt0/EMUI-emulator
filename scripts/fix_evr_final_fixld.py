with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find fix_ldconfig() function start and end
start_idx = c.find('fix_ldconfig() {')
if start_idx == -1:
    print('fix_ldconfig() not found')
else:
    # Find the end of the function - look for pin_selinux()
    end_idx = c.find('pin_selinux() {', start_idx)
    if end_idx == -1:
        print('pin_selinux() not found')
    else:
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

'''
    c = c[:start_idx] + new_func + c[end_idx:]
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('fix_ldconfig replaced with simple version')
