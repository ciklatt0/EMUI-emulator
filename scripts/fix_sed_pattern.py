import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix the sed pattern to match start servicemanager with optional whitespace
old = '''  # --- EVR-L29: Start system_server after servicemanager in init.rc ---
  sed -i '/^start servicemanager$/a\\    start system_server' "$ROOT/init.rc" 2>/dev/null'''

new = '''  # --- EVR-L29: Start system_server after servicemanager in init.rc ---
  sed -i '/[[:space:]]*start servicemanager[[:space:]]*$/a\\    start system_server' "$ROOT/init.rc" 2>/dev/null'''

if old in content:
    content = content.replace(old, new, 1)
    print("Fixed sed pattern for start servicemanager")
else:
    print("ERROR: Pattern not found")
    idx = content.find('start system_server')
    if idx != -1:
        print(f"Found start system_server at {idx}:")
        print(content[max(0,idx-100):idx+100])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
