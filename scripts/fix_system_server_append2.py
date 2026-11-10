with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find UI_EOF line and add on init start system_server right after it
old = '''UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"'''

new = '''UI_EOF

# --- EVR-L29: Start system_server via on init trigger ---
  echo "" >> "$ROOT/init.rc"
  echo "on init" >> "$ROOT/init.rc"
  echo "    start system_server" >> "$ROOT/init.rc"
  echo "### EVR-L29: on init start system_server appended ###"

  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added unconditional on init start system_server append after UI_EOF")
else:
    print("ERROR: Pattern not found")
    idx = content.find('UI_EOF')
    if idx != -1:
        print(f"UI_EOF at {idx}:")
        print(repr(content[idx:idx+200]))

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
