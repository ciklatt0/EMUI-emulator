with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix 1: Add debug output to linker64 fix in custom /init section
# Add "reached linker64 fix" echo before the if statement
old_linker = '''  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,'''

new_linker = '''  /bb/echo "### EVR-L29: reaching linker64 fix ###"
  # --- EVR-L29: Fix linker64 symlink ---------------------------------------
  # /system/bin/linker64 is a symlink to /apex/com.android.runtime/bin/linker64,'''

if old_linker in content:
    content = content.replace(old_linker, new_linker, 1)
    print("Added linker64 debug echo")
else:
    print("ERROR: linker64 block not found for debug echo")

# Fix 2: Add debug echo if linker64 condition passes
old_linker_if = '''  if [ -f /system/bin/bootstrap/linker64 ]; then'''
new_linker_if = '''  /bb/echo "### EVR-L29: checking /system/bin/bootstrap/linker64 ###"
  if [ -f /system/bin/bootstrap/linker64 ]; then
    /bb/echo "### EVR-L29: bootstrap/linker64 FOUND ###"'''

if old_linker_if in content:
    content = content.replace(old_linker_if, new_linker_if, 1)
    print("Added linker64 condition debug echo")
else:
    print("ERROR: linker64 if not found")

# Fix 3: Add debug echo if mount succeeds
old_linker_mount = '''    mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \\\n      && echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"'''
new_linker_mount = '''    mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \
      && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"
    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###"'''

if old_linker_mount in content:
    content = content.replace(old_linker_mount, new_linker_mount, 1)
    print("Added linker64 mount debug echo")
else:
    print("ERROR: linker64 mount not found - checking alternate")
    # Try without line continuation
    old_alt = 'mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null       && echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"'
    new_alt = 'mount -o bind /system-bin-tmp /system/bin/ 2>/dev/null \\\n      && /bb/echo "### EVR-L29: linker64 bind-mount via /system/bin/ overlay ###"\n    /bb/echo "### EVR-L29: linker64 bind-mount DONE ###"'
    if old_alt in content:
        content = content.replace(old_alt, new_alt, 1)
        print("Added linker64 debug echo (alt format)")
    else:
        print("ERROR: neither format found")

# Fix 4: Add standalone system_server service in init.rc section
# Find where zygote service is defined in init.rc and add system_server after it
old_zygote_rc = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote
    setenv ANDROID_DATA /data
    setenv ANDROID_ROOT /system
    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art
    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata
    setenv ANDROID_IOTA_ROOT /apex/com.android.iota
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system
    onrestart write /sys/android_power/request_state wake
    # onrestart write /sys/power/state on
    onrestart restart audioserver
    onrestart restart cameraserver
    onrestart restart media
    onrestart restart netd
    onrestart restart wificond
    # writepid /dev/cpuset/foreground/tasks /dev/blkio/foreground/tasks /dev/stune/foreground/tasks
    onrestart restart mygote
    # critical'''

new_zygote_rc = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    setenv ANDROID_DATA /data
    setenv ANDROID_ROOT /system
    setenv ANDROID_RUNTIME_ROOT /apex/com.android.art
    setenv ANDROID_TZDATA_ROOT /apex/com.android.tzdata
    setenv ANDROID_IOTA_ROOT /apex/com.android.iota
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system
    stdout /dev/kmsg
    stderr /dev/kmsg
    onrestart write /sys/android_power/request_state wake
    onrestart restart audioserver
    onrestart restart cameraserver
    onrestart restart media
    onrestart restart netd
    onrestart restart wificond

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server --start-system-server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg'''

if old_zygote_rc in content:
    content = content.replace(old_zygote_rc, new_zygote_rc, 1)
    print("Replaced zygote rc with system_server service")
else:
    print("ERROR: zygote rc block not found")
    # Try to find what the zygote section actually looks like
    import re
    match = re.search(r'service zygote.*?critical', content, re.DOTALL)
    if match:
        print(f"Found zygote section:\n{match.group()[:500]}")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
