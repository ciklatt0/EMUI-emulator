with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find the ADIM 1 line and insert critical removal before it
old = '# --- ADIM 1: rc agacini kopyala (dizin seviyesinde) -------------------------'
new = '''  # --- EVR-L29: Remove 'critical' from all services so init doesn't crash
  # when a service fails to link. Also comment out exec_start apexd-bootstrap
  # which can hang if apexd fails to link.
  if [ -f "$SRC/init.rc" ]; then
    sed -i 's/^    critical$/    # critical/' "$SRC/init.rc" 2>/dev/null
    sed -i 's/^    exec_start apexd-bootstrap$/    # exec_start apexd-bootstrap/' "$SRC/init.rc" 2>/dev/null
    m "### EVR-L29: Removed critical from init.rc services ###"
  fi
  if [ -f "$SRC/init.zygote64_32.rc" ]; then
    sed -i 's/^    critical$/    # critical/' "$SRC/init.zygote64_32.rc" 2>/dev/null
    m "### EVR-L29: Removed critical from init.zygote64_32.rc ###"
  fi

# --- ADIM 1: rc agacini kopyala (dizin seviyesinde) -------------------------'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('critical removal added to rclog')
else:
    print('HATA: ADIM 1 block bulunamadı')
