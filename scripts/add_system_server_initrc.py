import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find where surfaceflinger/bootanimation are added to init.rc (UI_EOF section)
# Add system_server right before UI_EOF
old_ui = '''on property:sys.boot_completed=1
    start bootanimation
UI_EOF'''

new_ui = '''on property:sys.boot_completed=1
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

if old_ui in content:
    content = content.replace(old_ui, new_ui, 1)
    print("Added system_server to init.rc UI section")
else:
    print("ERROR: UI_EOF pattern not found in init.rc section")
    # Try alternate pattern
    old_alt = '    start bootanimation\nUI_EOF'
    if old_alt in content:
        new_alt = '    start bootanimation\n\n# --- EVR-L29: SystemServer via app_process64 -------------------------------\nservice system_server /system/bin/app_process64 /system/bin --nice-name=system_server\n    class main\n    priority -20\n    user system\n    group system readproc reserved_disk\n    stdin /dev/null\n    stdout /dev/kmsg\n    stderr /dev/kmsg\n\nUI_EOF'
        content = content.replace(old_alt, new_alt, 1)
        print("Added system_server to init.rc UI section (alt format)")
    else:
        print("ERROR: Neither format found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
