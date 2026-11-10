with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix 1: Fix the concatenated start line in init.rc
# "start system_server / hwservicemanager / vndservicemanager" should be separate lines
old1 = '''start servicemanager
    start surfaceflinger
    start system_server / hwservicemanager / vndservicemanager'''

new1 = '''start servicemanager
    start surfaceflinger
    start system_server
    start hwservicemanager
    start vndservicemanager'''

count1 = content.count(old1)
print(f"Found {count1} occurrences of concatenated start line")

if count1 > 0:
    content = content.replace(old1, new1, 1)
    print("FIX: Separated start servicemanager/system_server/hwcomposer/vndservicemanager into separate lines")
else:
    print("WARNING: Concatenated start pattern not found")

# Fix 2: Add start system_server to servicemaker's onrestart
old_sm = '''service servicemanager /system/bin/servicemanager
    class core
    user system
    group system readproc reserved_disk
    socket servicemanager stream 660 root system
    onrestart restart inputflinger
    onrestart restart thermalservice'''

new_sm = '''service servicemanager /system/bin/servicemanager
    class core
    user system
    group system readproc reserved_disk
    socket servicemanager stream 660 root system
    onrestart restart inputflinger
    onrestart restart thermalservice
    onrestart start system_server'''

count2 = content.count(old_sm)
print(f"\nFound {count2} occurrences of servicemaker service definition")

if count2 > 0:
    content = content.replace(old_sm, new_sm, 1)
    print("FIX: Added start system_server to servicemaker's onrestart")
else:
    print("WARNING: servicemaker service pattern not found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
