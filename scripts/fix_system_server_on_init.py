import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find system_server service in init.rc section and wrap start in on init trigger
old = '''service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg
    start system_server

on property:sys.boot_completed=1'''

new = '''on init
    start system_server

service system_server /system/bin/app_process64 /system/bin --nice-name=system_server
    class main
    priority -20
    user system
    group system readproc reserved_disk
    stdin /dev/null
    stdout /dev/kmsg
    stderr /dev/kmsg

on property:sys.boot_completed=1'''

if old in content:
    content = content.replace(old, new, 1)
    print("Wrapped start system_server in on init trigger")
else:
    print("ERROR: Pattern not found")
    idx = content.find('service system_server')
    if idx != -1:
        print(f"Found at {idx}:")
        print(content[max(0,idx-50):idx+400])

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
