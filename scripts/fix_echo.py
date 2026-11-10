with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Fix: /bb/echo doesn't exist on host, use echo instead
old = '''    /bb/echo "### EVR-L29: zygote=running -> start system_server trigger added ###"'''
new = '''    echo "### EVR-L29: zygote=running -> start system_server trigger added ###"'''

if old in content:
    content = content.replace(old, new, 1)
    print("FIX: Changed /bb/echo to echo")
else:
    print("WARNING: /bb/echo pattern not found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
