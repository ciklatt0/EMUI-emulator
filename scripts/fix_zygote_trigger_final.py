with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add zygote=running -> start system_server trigger after the zygote+system_server patched echo
old = '''  echo "### EVR-L29: init.zygote64_32.rc zygote+system_server patched ###"
  fi

fi'''

new = '''  echo "### EVR-L29: init.zygote64_32.rc zygote+system_server patched ###"
  # Also start system_server when zygote starts
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
    # Show what's around line 335
    lines = content.split('\n')
    for i in range(330, 342):
        if i < len(lines):
            print(f'{i+1}: {lines[i]}')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
