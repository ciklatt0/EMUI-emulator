with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find zygote service definition and add start system_server to its onrestart
# Look for the zygote service definition pattern
old_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system'''

new_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system
    onrestart start system_server'''

count = content.count(old_zygote)
print(f"Found {count} occurrences of zygote service definition")

if count > 0:
    content = content.replace(old_zygote, new_zygote, 1)
    print("FIX: Added start system_server to zygote's onrestart!")
else:
    print("WARNING: zygote service definition not found!")
    # Search for any zygote service definition
    import re
    matches = re.findall(r'service zygote[^\n]*', content)
    for m in matches[:5]:
        print(f"  Found: {m.strip()}")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
