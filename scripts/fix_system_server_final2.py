with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find UI_EOF and add on init start system_server after it
# Look for the exact pattern: UI_EOF followed by echo and vendor HALs comment
old = '''UI_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until ready) ---'''

new = '''UI_EOF

# --- EVR-L29: Start system_server via on init trigger ---
  cat >> "$ROOT/init.rc" <<'SS_EOF'

on init
    start system_server
SS_EOF
  echo "### EVR-L29: UI servisleri eklendi (surfaceflinger, bootanimation) ###"
  # --- EVR-L29: vendor HALs start immediately (restart until ready) ---'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added on init start system_server block after UI_EOF")
else:
    print("ERROR: Pattern not found")
    # Show what's around UI_EOF
    idx = content.find('UI_EOF')
    if idx != -1:
        print(f"UI_EOF at {idx}:")
        print(content[max(0,idx-100):idx+300])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
