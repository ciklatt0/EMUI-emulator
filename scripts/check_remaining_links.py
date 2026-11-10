with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()
import re
# Find all namespace.default.links lines with context
for m in re.finditer(r'namespace\.default\.links[^\n]*', c):
    start = max(0, m.start() - 80)
    end = min(len(c), m.end() + 20)
    print(f'Context: ...{c[start:end]}...')
    print()
