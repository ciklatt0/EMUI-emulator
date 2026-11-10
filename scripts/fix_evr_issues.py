import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix 1: Line 150 - /bb/echo in host script should be echo
old1 = '/bb/echo "### EVR-L29: init.zygote64_32.rc kopyalandi initramfs kokuya ###"'
new1 = 'echo "### EVR-L29: init.zygote64_32.rc kopyalandi initramfs kokuya ###"'
count1 = c.count(old1)
if count1 > 0:
    c = c.replace(old1, new1, count1)
    print(f'Fix 1: {count1} x /bb/echo -> echo at line 150 area')
else:
    print('Fix 1: pattern not found')

# Fix 2: Add androidboot.zygote=zygote64_32 to KCMD
# Find the QEMU -append line with KCMD
old2 = 'androidboot.hwcrypto.enabled=true printk_ratelimit'
new2 = 'androidboot.hwcrypto.enabled=true androidboot.zygote=zygote64_32 printk_ratelimit'
count2 = c.count(old2)
if count2 > 0:
    c = c.replace(old2, new2, count2)
    print(f'Fix 2: {count2} x androidboot.zygote added to KCMD')
else:
    print('Fix 2: KCMD pattern not found')
    # Debug: find KCMD
    idx = c.find('KCMD')
    if idx != -1:
        print(f'  KCMD context: {repr(c[idx:idx+200])}')

# Fix 3: Hardcode RO_ZYG = zygote64_32 (ro.zygote prop not in build.prop files)
# Find where RO_ZYG is set
old3 = 'RO_ZYG=$(propof ro.zygote)'
new3 = '''# DIKKAT (EVR-L29): ro.zygote prop dosyalarda yok, androidboot.zygote
# kernel komut satirindan geliyor ama propof() dosyalardan okur.
# Hardcode edelim:
RO_ZYG="zygote64_32"'''
count3 = c.count(old3)
if count3 > 0:
    c = c.replace(old3, new3, count3)
    print(f'Fix 3: {count3} x RO_ZYG hardcoded to zygote64_32')
else:
    print('Fix 3: RO_ZYG=$(propof ro.zygote) not found')

# Fix 4: Rewrite fix_ldconfig() - replace broken brace block
start_idx = c.find('fix_ldconfig() {')
if start_idx != -1:
    end_idx = c.find('pin_selinux() {', start_idx)
    if end_idx != -1:
        new_func = '''fix_ldconfig() {
  CFG=/linkerconfig/ld.config.txt
  [ -d /apex/com.android.runtime ] || return 0
  # DIKKAT (EVR-L29): her turda konfigurasyonu sifirdan olustur.
  # init'in linkerconfig'i dosyayi bozabilir, bu yuzden her turda
  # yeniden yazmak en guvenlidir.
  mkdir -p /linkerconfig 2>/bb/null
  /bb/echo "# HARMONY-EMU apex yollari basliyor" > "$CFG"
  /bb/echo "dir.system = /system/bin/" >> "$CFG"
  /bb/echo "dir.system = /system/lib64/" >> "$CFG"
  /bb/echo "dir.vendor = /vendor/bin/" >> "$CFG"
  /bb/echo "dir.vendor = /vendor/lib64/" >> "$CFG"
  /bb/echo "" >> "$CFG"
  /bb/echo "[system]" >> "$CFG"
  /bb/echo "namespace.default.isolated = false" >> "$CFG"
  /bb/echo "namespace.default.visible = true" >> "$CFG"
  /bb/echo "namespace.default.search.paths = /system/bin:/system/lib64:/vendor/bin:/vendor/lib64" >> "$CFG"
  /bb/echo "namespace.default.permitted.paths = /system/bin:/system/lib64:/vendor/bin:/vendor/lib64" >> "$CFG"
  for a in /apex/*/; do
    [ -d "$a/lib64" ] || continue
    lname=${a#/apex/}; case "$lname" in */) lname=${lname%/} ;; esac
    /bb/echo "namespace.default.search.paths += /apex/$lname/lib64" >> "$CFG"
    /bb/echo "namespace.default.permitted.paths += /apex/$lname/lib64" >> "$CFG"
    if [ -d "$a/lib64/bionic" ]; then
      /bb/echo "namespace.default.search.paths += /apex/$lname/lib64/bionic" >> "$CFG"
      /bb/echo "namespace.default.permitted.paths += /apex/$lname/lib64/bionic" >> "$CFG"
    fi
  done
  m "### ld.config.txt sifirdan olusturuldu ###"
  ld_ok=1
}

'''
        c = c[:start_idx] + new_func + c[end_idx:]
        print('Fix 4: fix_ldconfig() rewritten')
    else:
        print('Fix 4: pin_selinux() not found')
else:
    print('Fix 4: fix_ldconfig() not found')

# Fix 5: Rewrite ensure_ldconfig_final() - replace broken brace block
start_idx = c.find('ensure_ldconfig_final() {')
if start_idx != -1:
    end_idx = c.find('SUPERVISE_APEX', start_idx)
    # Find the end of the function - look for the closing '}' followed by blank line
    # Actually let's find the next function or section
    end_idx2 = c.find('\\n# --- ', start_idx + 1)
    if end_idx2 != -1:
        new_func2 = '''ensure_ldconfig_final() {
  CFG=/linkerconfig/ld.config.txt
  [ -f "$CFG" ] || return 0
  # APEX yolu var mi kontrol et
  if ! /bb/grep -q '/apex/' "$CFG" 2>/bb/null; then
    m "### ld.config.txt'de APEX yolu yok; sifirdan uretiliyor ###"
    mkdir -p /linkerconfig 2>/bb/null
    /bb/echo "# HARMONY-EMU final config" > "$CFG"
    /bb/echo "dir.system = /system/bin/" >> "$CFG"
    /bb/echo "dir.system = /system/lib64/" >> "$CFG"
    /bb/echo "dir.vendor = /vendor/bin/" >> "$CFG"
    /bb/echo "dir.vendor = /vendor/lib64/" >> "$CFG"
    /bb/echo "" >> "$CFG"
    /bb/echo "[system]" >> "$CFG"
    /bb/echo "namespace.default.isolated = false" >> "$CFG"
    /bb/echo "namespace.default.visible = true" >> "$CFG"
    /bb/echo "namespace.default.search.paths = /system/bin:/system/lib64:/vendor/bin:/vendor/lib64" >> "$CFG"
    /bb/echo "namespace.default.permitted.paths = /system/bin:/system/lib64:/vendor/bin:/vendor/lib64" >> "$CFG"
    for entry in __APEX_LIST__; do
      apname=${entry##*:}
      /bb/echo "namespace.default.search.paths += /apex/$apname/lib64" >> "$CFG"
      /bb/echo "namespace.default.permitted.paths += /apex/$apname/lib64" >> "$CFG"
      if [ -d "/apex/$apname/lib64/bionic" ]; then
        /bb/echo "namespace.default.search.paths += /apex/$apname/lib64/bionic" >> "$CFG"
        /bb/echo "namespace.default.permitted.paths += /apex/$apname/lib64/bionic" >> "$CFG"
      fi
    done
    m "### ld.config.txt son definitif versiyon yazildi ###"
  fi
}

'''
        c = c[:start_idx] + new_func2 + c[end_idx2:]
        print('Fix 5: ensure_ldconfig_final() rewritten')
    else:
        print('Fix 5: end boundary not found')
else:
    print('Fix 5: ensure_ldconfig_final() not found')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)

print('Tum duzeltmeler tamamlandi')