with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

print("=== Current state ===")
print(f"'start system_server' count: {content.count('start system_server')}")
print(f"'service system_server' count: {content.count('service system_server')}")
print(f"'start surfaceflinger' count: {content.count('start surfaceflinger')}")
print(f"'service surfaceflinger' count: {content.count('service surfaceflinger')}")

# Fix 1: Add start system_server to servicemaker's onrestart
# Find servicemaker's service definition and add onrestart start system_server
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

if old_sm in content:
    content = content.replace(old_sm, new_sm, 1)
    print("FIX: Added start system_server to servicemaker's onrestart")
else:
    print("WARNING: servicemaker onrestart pattern not found")

# Fix 2: Add start surfaceflinger right after start servicemanager in init.rc
old_sf = '''start servicemanager
    start system_server
    start system_server'''

new_sf = '''start servicemanager
    start surfaceflinger
    start system_server
    start system_server'''

if old_sf in content:
    content = content.replace(old_sf, new_sf, 1)
    print("FIX: Added start surfaceflinger after start servicemanager")
else:
    print("WARNING: servicemanager start pattern not found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
