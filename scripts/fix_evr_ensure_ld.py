with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Fix ensure_ldconfig_final() - replace broken brace block
start_idx = c.find('ensure_ldconfig_final() {')
if start_idx == -1:
    print('ERROR: ensure_ldconfig_final() not found')
else:
    # Find the end - look for the closing pattern
    end_marker = '\n# --- printk susturmayi kapat'
    end_idx = c.find(end_marker, start_idx)
    if end_idx == -1:
        print('ERROR: end marker not found')
    else:
        new_func = '''ensure_ldconfig_final() {
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
        c = c[:start_idx] + new_func + c[end_idx:]
        with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
            f.write(c)
        print('ensure_ldconfig_final() rewritten successfully')