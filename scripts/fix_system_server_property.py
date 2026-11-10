with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add start system_server when servicemaker becomes running
# Find where UI_EOF section ends and add before vendor HALs comment
old = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until servicemaker ready) ---'''

new = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"

  # --- EVR-L29: Start system_server when servicemaker is running ---
  # servicemaker starts at boot; when it becomes running, start system_server.
  # This ensures system_server starts after binder/servicemaker is available.
  echo "" >> "$ROOT/init.rc"
  echo "on property:init.svc.servicemaker=running" >> "$ROOT/init.rc"
  echo "    start system_server" >> "$ROOT/init.rc"
  echo "### EVR-L29: on property start system_server appended ###"

  # --- EVR-L29: vendor HALs start immediately (restart until servicemaker ready) ---'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added on property start system_server appended to init.rc")
else:
    print("ERROR: Pattern not found")
    idx = content.find('### EVR-L29: UI servisleri eklendi')
    if idx != -1:
        print(f"Found at {idx}:")
        print(repr(content[idx:idx+200]))

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
