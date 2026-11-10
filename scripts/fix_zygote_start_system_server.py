import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Restore --start-system-server to zygote in init.zygote64_32.rc
old_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote'''
new_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote'''

count = content.count(old_zygote)
print(f"Found {count} occurrences of zygote service without --start-system-server")

if count > 0:
    content = content.replace(old_zygote, new_zygote, 1)
    print("Restored --start-system-server to zygote")
else:
    print("WARNING: zygote service without --start-system-server not found")
    # Check if --start-system-server is already there
    if '--start-system-server' in content:
        print("--start-system-server already present in zygote service")
    else:
        print("Could not find zygote service definition at all")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
