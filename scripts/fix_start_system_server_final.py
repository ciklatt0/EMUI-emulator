import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add sed command to insert start system_server after start servicemanager in init.rc
# Find a good insertion point - after the init.zygote64_32.rc patches
old = '''  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"
fi'''

new = '''  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"

  # --- EVR-L29: Start system_server after servicemanager in init.rc ---
  if [ -f "$ROOT/init.rc" ]; then
    sed -i '/^start servicemanager$/a\    start system_server' "$ROOT/init.rc" 2>/dev/null
    echo "### EVR-L29: start system_server added to init.rc ###"
  fi

fi'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added start system_server sed command to init.rc")
else:
    print("ERROR: Pattern not found")
    idx = content.find('init.zygote64_32.rc critical/writepid/powerstate yamalandi')
    if idx != -1:
        print(f"Found at {idx}:")
        print(content[max(0,idx-100):idx+200])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
