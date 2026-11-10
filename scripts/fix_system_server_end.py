import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add start system_server at end of init.rc via new on init block
# Find where UI_EOF ends (end of init.rc creation)
old_ui_end = '''UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until ready) ---'''

new_ui_end = '''UI_EOF

# --- EVR-L29: Start system_server via on init trigger ---
  cat >> "$ROOT/init.rc" <<'SS_EOF'

on init
    start system_server
SS_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until ready) ---'''

if old_ui_end in content:
    content = content.replace(old_ui_end, new_ui_end, 1)
    print("Added on init start system_server block at end of init.rc")
else:
    print("ERROR: UI_EOF pattern not found")
    idx = content.find('UI_EOF')
    if idx != -1:
        print(f"Found UI_EOF at {idx}:")
        print(content[max(0,idx-100):idx+200])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
