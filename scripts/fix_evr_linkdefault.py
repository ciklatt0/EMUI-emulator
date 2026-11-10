with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
# Remove the bad link.default line
old = '  /bb/echo "link.default = default,system${APEXNS:+,$APEXNS}" >> /tmp/ld.link'
if old in c:
    c = c.replace(old, '', 1)
    print('Bad link.default line removed')
else:
    print('Bad link.default line not found')
    # Show what's around link.default
    import re
    for m in re.finditer(r'link\.default[^\n]*', c):
        start = max(0, m.start() - 40)
        end = min(len(c), m.end() + 40)
        print(f'Context: ...{c[start:end]}...')
        print()

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(c)
print('Done')
