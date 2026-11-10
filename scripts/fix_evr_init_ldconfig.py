with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find where exec /system/bin/init is in the /init script
# Add ld.config.txt generation BEFORE exec init
old = '''exec /system/bin/init "$@"
INIT_EOF'''

new = '''# --- EVR-L29: ld.config.txt'i ANDROID INIT'TEN ONCE olustur --------------
# Linker config'i exec init'DEN ONCE hazirlamak zorunlu; aksi halde
# ilk servisler (ueventd, servicemanager, zygote) baglanamaz ve
# init "Attempted to kill init" ile panik yapar.
# APEX'ler mountapex ile zaten bagli; onlardan yollarini toplayip
# ld.config.txt yaziyoruz.
mkdir -p /linkerconfig 2>/dev/null
{
  /bb/echo "# HARMONY-EMU bootstrap linker config"
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
} > /linkerconfig/ld.config.txt 2>/dev/null
echo "  ld.config.txt: $(grep -c '/apex/' /linkerconfig/ld.config.txt 2>/dev/null) APEX yolu, $(wc -l < /linkerconfig/ld.config.txt 2>/dev/null) satir"

exec /system/bin/init "$@"
INIT_EOF'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('ld.config.txt generation added to /init before exec init')
else:
    print('ERROR: exec /system/bin/init pattern not found')
    # Debug
    idx = c.find('exec /system/bin/init')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx-50:idx+50])}')