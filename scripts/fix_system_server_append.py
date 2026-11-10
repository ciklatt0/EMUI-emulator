with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find where init.rc creation ends (after UI_EOF section)
# Add unconditional append of on init { start system_server }
old = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until ready) ---'''

new = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"

  # --- EVR-L29: Start system_server via on init trigger (unconditional) ---
  echo "" >> "$ROOT/init.rc"
  echo "on init" >> "$ROOT/init.rc"
  echo "    start system_server" >> "$ROOT/init.rc"
  echo "### EVR-L29: on init start system_server appended ###"

  # --- EVR-L29: vendor HALs start immediately (restart until ready) ---'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added unconditional on init start system_server append to init.rc")
else:
    print("ERROR: Pattern not found")
    idx = content.find('### EVR-L29: UI servisleri eklendi')
    if idx != -1:
        print(f"Found at {idx}:")
        print(content[max(0,idx-100):idx+200])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
