import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Add onrestart start system_server to zygote in init.zygote64_32.rc
# Find where zygote's onrestart actions end in init.zygote64_32.rc patching
old = '''    sed -i '/onrestart restart wificond/d' "$ROOT/init.zygote64_32.rc" 2>/dev/null'''

# Check if there's already a wificond onrestart removal
if 'onrestart restart wificond' in content:
    print("Found onrestart restart wificond in script")
    # Add start system_server after wificond restart
    old2 = '''    sed -i '/onrestart restart wificond/d' "$ROOT/init.zygote64_32.rc" 2>/dev/null'''
    new2 = '''    sed -i '/onrestart restart wificond/d' "$ROOT/init.zygote64_32.rc" 2>/dev/null
    sed -i '/onrestart restart wificond/a\\    onrestart start system_server' "$ROOT/init.zygote64_32.rc" 2>/dev/null'''
    if old2 in content:
        content = content.replace(old2, new2, 1)
        print("Added onrestart start system_server after wificond restart removal")
    else:
        print("Could not find wificond removal line")
else:
    print("onrestart restart wificond not found in script")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
