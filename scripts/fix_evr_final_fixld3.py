with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Remove namespace.default.links = system (invalid namespace reference)
old = '''    /bb/echo "namespace.default.links = system"'''

new = '''    # namespace.default.links = system  # Disabled: system namespace not defined'''

if old in c:
    c = c.replace(old, new, 1)
    with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
        f.write(c)
    print('namespace.default.links removed')
else:
    print('namespace.default.links = system not found')
    import re
    matches = re.findall(r'namespace\.default\.links[^\n]*', c)
    for m in matches:
        print(f'  {m}')
