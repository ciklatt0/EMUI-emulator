import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()
for match in re.finditer(r'init\.rc', content):
    pos = match.start()
    context = content[max(0,pos-80):pos+80]
    if 'cp' in context or 'copy' in context.lower() or 'sys-mnt' in context:
        print(f'Position {pos}:')
        print(context)
        print('---')
