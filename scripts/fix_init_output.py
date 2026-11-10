with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix: Change init's output redirect from /bb/init.out (lost inside initramfs)
# to /dev/console so we can see init's service start messages in QEMU log
old_redirect = 'exec 1>>"$INITLOG" 2>&1'
new_redirect = 'exec 1>/dev/console 2>&1'

count = content.count(old_redirect)
print(f"Found {count} occurrences of exec redirect")

if count > 0:
    content = content.replace(old_redirect, new_redirect, 1)
    print("FIX: Changed init output redirect to /dev/console")
else:
    print("WARNING: exec redirect pattern not found")
    # Check what's actually there
    for i, line in enumerate(content.split('\n'), 1):
        if 'INITLOG' in line and 'exec' in line:
            print(f'  Line {i}: {line.rstrip()}')

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
