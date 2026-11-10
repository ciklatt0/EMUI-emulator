with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find zygote service definition and add start system_server to onrestart
# Remove --start-system-server from zygote since it doesn't work
old_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote'''

new_zygote = '''service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --socket-name=zygote
    onrestart start system_server'''

count = content.count(old_zygote)
print(f"Found {count} occurrences of zygote service definition")

if count > 0:
    content = content.replace(old_zygote, new_zygote, 1)
    print("FIX: Removed --start-system-server from zygote, added onrestart start system_server")
else:
    print("WARNING: zygote service definition not found in expected format!")
    # Try alternate patterns
    import re
    zygote_matches = list(re.finditer(r'service zygote[^\n]*', content))
    print(f"Found {len(zygote_matches)} zygote service lines:")
    for m in zygote_matches:
        print(f"  {m.group().strip()}")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
