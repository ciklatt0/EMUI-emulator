with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find where UI_EOF section ends and add property trigger after it
# Match just the echo line
old = '  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"'

new = '''  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"

  # --- EVR-L29: Start system_server when servicemanager is running ---
  echo "" >> "$ROOT/init.rc"
  echo "on property:init.svc.servicemanager=running" >> "$ROOT/init.rc"
  echo "    start system_server" >> "$ROOT/init.rc"
  echo "### EVR-L29: on property start system_server appended ###"'''

count = content.count(old)
print(f"Found {count} occurrences of echo UI servisleri line")

if count > 0:
    content = content.replace(old, new, 1)
    print("Added on property start system_server appended to init.rc")
else:
    print("ERROR: Pattern not found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
