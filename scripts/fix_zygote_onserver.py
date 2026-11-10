with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add start system_server to zygote's onrestart
old_zygote = '''service arkprobe /system/bin/app_process64 -Xzygote /system/bin --zygote --nice-name=zygote64 --socket-name=ark'''

new_zygote = '''service arkprobe /system/bin/app_process64 -Xzygote /system/bin --zygote --nice-name=zygote64 --socket-name=ark
    onrestart start system_server'''

count = content.count(old_zygote)
print(f"Found {count} occurrences of zygote service definition")

if count > 0:
    content = content.replace(old_zygote, new_zygote, 1)
    print("FIX: Added onrestart start system_server to zygote service!")
else:
    print("ERROR: zygote service definition not found!")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
