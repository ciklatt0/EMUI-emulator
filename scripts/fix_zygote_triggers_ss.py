with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add start system_server when zygote starts
old = '''  echo "### EVR-L29: init.zygote64_32.rc zygote+system_server patched ###"
fi'''

new = '''  echo "### EVR-L29: init.zygote64_32.rc zygote+system_server patched ###"
  # Also start system_server when zygote starts (zygote has --start-system-server)
  if ! /bb/grep -q 'init.svc.zygote=running' "$ROOT/init.rc" 2>/dev/null; then
    cat >> "$ROOT/init.rc" <<'ZY_EOF'

on property:init.svc.zygote=running
    start system_server

ZY_EOF
    /bb/echo "### EVR-L29: zygote=running -> start system_server trigger added ###"
  fi
fi'''

if old in content:
    content = content.replace(old, new, 1)
    print("FIX: Added zygote=running -> start system_server trigger")
else:
    print("ERROR: Pattern not found")
    idx = content.find('zygote+system_server patched')
    if idx != -1:
        print(f'Found at {idx}:')
        print(content[idx:idx+200])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
