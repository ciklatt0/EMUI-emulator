with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find the awk command that generates ld.config.txt and add a fallback
# for when CFG doesn't exist yet
old = '''  /bb/awk -v ins="$PATHS" -v per="$PERTM" '
    { print }
    !done1 && /^namespace\\.default\\.search\\.paths/ { printf "%s\\n", ins; done1=1 }
    !done2 && /^namespace\\.default\\.permitted\\.paths/ { printf "%s\\n", per; done2=1 }
  ' "$CFG" > /tmp/ld.new 2>/bb/null'''

new = '''  # DIKKAT (EVR-L29): CFG dosyasi yoksa (ilk boot), sifirdan olustur.
    # Aksi takdirde awk dosya yokken cikamaz ve config olusmaz.
    if [ ! -f "$CFG" ]; then
      mkdir -p /linkerconfig 2>/bb/null
      {
        /bb/echo "# HARMONY-EMU apex yollari basliyor"
        /bb/echo "dir.vendor = /vendor/bin/"
        /bb/echo "dir.vendor = /vendor/lib64/"
        /bb/echo "dir.vendor = /vendor/lib64/hw/"
        /bb/echo ""
        /bb/echo "[system]"
        /bb/echo "namespace.default.isolated = false"
        /bb/echo "namespace.default.visible = true"
        /bb/printf "%s\\n" "$PATHS"
        /bb/printf "%s\\n" "$PERTM"
        /bb/echo "namespace.default.links = system"
      } > "$CFG" 2>/bb/null
      m "### ld.config.txt sifirdan olusturuldu ###"
      ld_ok=1
    else
      /bb/awk -v ins="$PATHS" -v per="$PERTM" '
    { print }
    !done1 && /^namespace\\.default\\.search\\.paths/ { printf "%s\\n", ins; done1=1 }
    !done2 && /^namespace\\.default\\.permitted\\.paths/ { printf "%s\\n", per; done2=1 }
  ' "$CFG" > /tmp/ld.new 2>/bb/null
    fi'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('CFG yokken sifirdan olusturma eklendi')
else:
    print('Old awk block not found')
    import re
    # Show what's around the awk command
    idx = c.find('/bb/awk -v ins="\\$PATHS"')
    if idx != -1:
        print(f'Found at {idx}: {repr(c[idx:idx+500])}')
