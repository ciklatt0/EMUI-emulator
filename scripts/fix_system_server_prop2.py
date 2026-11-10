with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add start system_server when servicemanager becomes running
old = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until servicemanager ready) ---'''

new = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"

  # --- EVR-L29: Start system_server when servicemanager is running ---
  # servicemanager starts at boot; when it becomes running, start system_server.
  echo "" >> "$ROOT/init.rc"
  echo "on property:init.svc.servicemanager=running" >> "$ROOT/init.rc"
  echo "    start system_server" >> "$ROOT/init.rc"
  echo "### EVR-L29: on property start system_server appended ###"

  # --- EVR-L29: vendor HALs start immediately (restart until servicemanager ready) ---'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added on property start system_server appended to init.rc")
else:
    print("ERROR: Pattern not found")
    idx = content.find('### EVR-L29: UI servisleri eklendi')
    if idx != -1:
        print(f"Found at {idx}:")
        print(repr(content[idx:idx+300]))

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
