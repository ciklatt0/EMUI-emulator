import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix 1: Add class_start main to init.rc before class_start core (or at beginning)
# Find where to add it - look for on init or start servicemanager
if 'class_start main' not in content:
    # Add class_start main in an on init block at the beginning of init.rc
    # Find a good insertion point - after the init.rc header, before first service
    init_rc_start = content.find('cat >"$ROOT/init.rc"')
    if init_rc_start != -1:
        # Find the first "on init" or "service " in init.rc section
        init_section = content[init_rc_start:init_rc_start+5000]
        # Look for first service definition or on trigger
        first_service = init_section.find('\nservice ')
        first_on = init_section.find('\non ')
        insert_pos = init_rc_start
        if first_service != -1 and (first_on == -1 or first_service < first_on):
            insert_pos = init_rc_start + first_service
        elif first_on != -1:
            insert_pos = init_rc_start + first_on
        
        class_start_main = '''on init
    class_start main

'''
        content = content[:insert_pos] + class_start_main + content[insert_pos:]
        print("Added class_start main to init.rc")
    else:
        print("ERROR: Could not find init.rc section")
else:
    print("class_start main already in boot script")

# Fix 2: Restore --start-system-server to zygote in init.zygote64_32.rc
# Find the zygote service in init.zygote64_32.rc section and add --start-system-server
old_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote'''
new_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote'''

if old_zygote in content:
    content = content.replace(old_zygote, new_zygote, 1)
    print("Restored --start-system-server to zygote")
else:
    print("WARNING: Could not find zygote service to restore --start-system-server")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
