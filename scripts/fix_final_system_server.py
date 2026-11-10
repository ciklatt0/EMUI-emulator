import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find where init.rc patching loop ends and add start system_server
old = '''      sed -i 's/^    exec -- \\/system\\/bin\\/vdc/    # exec -- \\/system\\/bin\\/vdc/' "$ROOT/$rcfile" 2>/dev/null
      echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---'''

new = '''      sed -i 's/^    exec -- \\/system\\/bin\\/vdc/    # exec -- \\/system\\/bin\\/vdc/' "$ROOT/$rcfile" 2>/dev/null
      echo "### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###"
    fi
  done

  # --- EVR-L29: Start system_server right after servicemanager ---
  sed -i '/[[:space:]]*start servicemanager[[:space:]]*$/a\    start system_server' "$ROOT/init.rc" 2>/dev/null

  # --- EVR-L29: UI servisleri ekle (SurfaceFlinger, bootanimation) ---'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added start system_server sed command after init.rc patching loop")
else:
    print("ERROR: Pattern not found")
    idx = content.find('### EVR-L29: $rcfile kopyalandi ve yamalandi (initramfs koku) ###')
    if idx != -1:
        print(f"Found echo at {idx}")
        print(content[max(0,idx-200):idx+200])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
