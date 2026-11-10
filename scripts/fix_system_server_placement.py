import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find and replace the system_server in UI_EOF section (it's inside on property:sys.boot_completed=1)
# We need to move it OUT of that block
old_system_server = '''on property:sys.boot_completed=1
    start bootanimation

# --- EVR-L29: SystemServer via app_process64 -------------------------------
service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg

UI_EOF'''

new_system_server = '''service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg

on property:sys.boot_completed=1
    start bootanimation

UI_EOF'''

if old_system_server in content:
    content = content.replace(old_system_server, new_system_server, 1)
    print("Moved system_server out of boot_completed block")
else:
    print("ERROR: system_server in UI_EOF not found")
    # Try to find what's actually there
    idx = content.find('start bootanimation')
    if idx != -1:
        start = max(0, idx - 200)
        end = min(len(content), idx + 200)
        print(f"Found 'start bootanimation' at {idx}:")
        print(content[start:end])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
