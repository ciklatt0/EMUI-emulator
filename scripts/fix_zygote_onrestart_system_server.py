import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add start system_server to zygote's onrestart actions in init.zygote64_32.rc
old_zygote_onrestart = '''    onrestart restart wificond

service system_server'''

new_zygote_onrestart = '''    onrestart restart wificond
    onrestart start system_server

service system_server'''

count = content.count(old_zygote_onrestart)
print(f"Found {count} occurrences of zygote onrestart block")

if count > 0:
    content = content.replace(old_zygote_onrestart, new_zygote_onrestart, 1)
    print("Added start system_server to zygote's onrestart")
else:
    print("WARNING: zygote onrestart block not found")
    # Check if system_server is already in onrestart
    if 'onrestart start system_server' in content:
        print("start system_server already in zygote onrestart")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
