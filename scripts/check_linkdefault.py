with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
import re
# Find all link.default references
matches = re.findall(r'link\.default[^\n]*', c)
print(f'Total link.default references: {len(matches)}')
for m in matches:
    print(f'  {m[:100]}')
