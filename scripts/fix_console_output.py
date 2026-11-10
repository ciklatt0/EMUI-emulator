with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix: Remove the /dev/kmsg redirect, let output go to console
# The exec 1>/dev/kmsg might not work in QEMU initramfs
old_redirect = 'exec 1>/dev/kmsg 2>&1'
new_redirect = '# exec output goes to console (console=ttyAMA0,115200)'

count = content.count(old_redirect)
print(f"Found {count} occurrences of redirect")

if count > 0:
    content = content.replace(old_redirect, new_redirect, 1)
    print("FIX: Removed /dev/kmsg redirect, output goes to console")
else:
    print("WARNING: redirect not found")

# Also make sure linker64 echo goes to console (not just /dev/kmsg)
old_echo = '/bb/echo "### EVR-L29: reaching linker64 fix ###" >/dev/kmsg 2>&1'
new_echo = '/bb/echo "### EVR-L29: reaching linker64 fix ###"'

if old_echo in content:
    content = content.replace(old_echo, new_echo, 1)
    print("FIX: Linker64 echo goes to console")
else:
    print("WARNING: linker64 echo pattern not found")

old_echo2 = '/bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###" >/dev/kmsg 2>&1'
new_echo2 = '/bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###"'

if old_echo2 in content:
    content = content.replace(old_echo2, new_echo2, 1)
    print("FIX: Linker64 checking echo goes to console")

old_echo3 = 'mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \\\n      && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###" >/dev/kmsg 2>&1'
new_echo3 = 'mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \\\n      && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"'

if old_echo3 in content:
    content = content.replace(old_echo3, new_echo3, 1)
    print("FIX: Linker64 mount echo goes to console")

old_echo4 = '    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###" >/dev/kmsg 2>&1'
new_echo4 = '    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###"'

if old_echo4 in content:
    content = content.replace(old_echo4, new_echo4, 1)
    print("FIX: Linker64 done echo goes to console")

old_echo5 = '  else\n    /bb/echo "### EVR-L29: ERROR: bootstrap/linker64 NOT FOUND! ###" >/dev/kmsg 2>&1\n  fi'
new_echo5 = '  else\n    /bb/echo "### EVR-L29: ERROR: bootstrap/linker64 NOT FOUND! ###"\n  fi'

if old_echo5 in content:
    content = content.replace(old_echo5, new_echo5, 1)
    print("FIX: Linker64 error echo goes to console")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
