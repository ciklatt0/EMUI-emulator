with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
# Find actual class_start core command (not in comments)
import re
for match in re.finditer(r'class_start core', content):
    print(f'Position {match.start()}:')
    print(content[max(0,match.start()-100):match.start()+100])
    print()
    print('---')
    if match.start() > 50000:  # Only show first few
        break
