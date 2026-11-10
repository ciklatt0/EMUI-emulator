with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find the end of init.zygote64_32.rc patches (after "critical/writepid/powerstate yamalandi")
old_end = '''  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"
fi'''

new_end = '''  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"

  # --- EVR-L29: Fix zygote rc - remove --start-system-server, add stdout/stderr, add system_server ---
  if [ -f "$ROOT/init.zygote64_32.rc" ]; then
    # Remove --start-system-server from zygote (we'll start system_server separately)
    sed -i 's/--start-system-server //' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    # Remove invalid onrestart restart mygote
    sed -i '/onrestart restart mygote/d' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    # Add stdout/stderr to zygote for debugging
    if ! /bb/grep -q 'stdout /dev/kmsg' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
      sed -i '/^socket usap_pool_primary/a\\    stdout /dev/kmsg\\n    stderr /dev/kmsg' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    fi
    # Add standalone system_server service
    if ! /bb/grep -q 'service system_server' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
      cat >> "$ROOT/init.zygote64_32.rc" << 'SS_EOF'

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg
SS_EOF
      echo "### EVR-L29: system_server service added to init.zygote64_32.rc ###"
    fi
    echo "### EVR-L29: init.zygote64_32.rc zygote+system_server patched ###"
  fi

fi'''

if old_end in content:
    content = content.replace(old_end, new_end, 1)
    print("Added zygote+system_server patch to boot script")
else:
    print("ERROR: Could not find the end of init.zygote64_32.rc patches")
    # Try alternate
    old_alt = '''  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"
fi
# /sys ve /sys/fs/selinux VAR OLMALI'''
    if old_alt in content:
        new_alt = '''  echo "### EVR-L29: init.zygote64_32.rc critical/writepid/powerstate yamalandi ###"

  # --- EVR-L29: Fix zygote rc - remove --start-system-server, add stdout/stderr, add system_server ---
  if [ -f "$ROOT/init.zygote64_32.rc" ]; then
    sed -i 's/--start-system-server //' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    sed -i '/onrestart restart mygote/d' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    if ! /bb/grep -q 'stdout /dev/kmsg' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
      sed -i '/^socket usap_pool_primary/a\\    stdout /dev/kmsg\\n    stderr /dev/kmsg' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    fi
    if ! /bb/grep -q 'service system_server' "$ROOT/init.zygote64_32.rc" 2>/dev/null; then
      cat >> "$ROOT/init.zygote64_32.rc" << 'SS_EOF'

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg
SS_EOF
      echo "### EVR-L29: system_server service added to init.zygote64_32.rc ###"
    fi
    echo "### EVR-L29: init.zygote64_32.rc zygote+system_server patched ###"
  fi

fi
# /sys ve /sys/fs/selinux VAR OLMALI'''
        content = content.replace(old_alt, new_alt, 1)
        print("Added zygote+system_server patch (alt format)")
    else:
        print("ERROR: Neither format found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
