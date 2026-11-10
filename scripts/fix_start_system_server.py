import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find the system_server service definition in init.rc section and add explicit start
old = '''service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg

on property:sys.boot_completed=1'''

new = '''service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg
    start system_server

on property:sys.boot_completed=1'''

if old in content:
    content = content.replace(old, new, 1)
    print("Added explicit start system_server")
else:
    print("ERROR: Pattern not found")
    # Show what's actually there
    idx = content.find('service system_server')
    if idx != -1:
        print(f"Found at {idx}:")
        print(content[max(0,idx-50):idx+300])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
