with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

print("=== Current state ===")
print(f"'start system_server' count: {content.count('start system_server')}")
print(f"'service system_server' count: {content.count('service system_server')}")

# Find zygote service definition
import re
zygote_matches = list(re.finditer(r'service zygote[^\n]*', content))
print(f"\nFound {len(zygote_matches)} zygote service lines:")
for m in zygote_matches:
    print(f"  {m.group().strip()}")

# Fix 1: Remove --start-system-server from zygote, add onrestart start system_server
old_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote'''

new_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    onrestart start system_server'''

count1 = content.count(old_zygote)
print(f"\nFound {count1} occurrences of zygote service with --start-system-server")

if count1 > 0:
    content = content.replace(old_zygote, new_zygote, 1)
    print("FIX: Removed --start-system-server from zygote, added onrestart start system_server")
else:
    print("WARNING: zygote service with --start-system-server not found!")
    # Try alternate pattern
    old_zygote2 = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote'''
    if old_zygote2 in content:
        new_zygote2 = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    onrestart start system_server'''
        if old_zygote2 in content:
            content = content.replace(old_zygote2, new_zygote2, 1)
            print("FIX: Added onrestart start system_server to zygote (alt format)")
        else:
            print("ERROR: zygote service not found in any format!")

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
    print("FIX: Added start system_server to servicemaker's onrestart!")
else:
    print("WARNING: servicemaker service pattern not found!")
    # Try alternate - just find servicemanager service line
    sm_matches = list(re.finditer(r'service servicemanager[^\n]*', content))
    print(f"Found {len(sm_matches)} servicemanager service lines:")
    for m in sm_matches:
        print(f"  {m.group().strip()}")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
