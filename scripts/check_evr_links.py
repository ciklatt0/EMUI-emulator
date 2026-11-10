with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
import re
# Check for link.default
if 'link.default = default' in c:
    print('WARNING: link.default still present!')
else:
    print('link.default removed OK')
# Check for namespace.default.links echo
links = re.findall(r'echo "namespace\.default\.links[^\n]*', c)
print(f'Remaining echo namespace.default.links: {len(links)}')
for l in links[:5]:
    print(f'  {l[:80]}')
# Check for sed cleanup
if 'sed -i' in c and 'namespace.default.links' in c:
    print('sed cleanup found OK')
else:
    print('sed cleanup NOT found')
