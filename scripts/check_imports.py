import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

for match in re.finditer(r'import.*zygote', content):
    start = max(0, match.start() - 100)
    end = min(len(content), match.end() + 100)
    print(f'--- Position {match.start()} ---')
    print(content[start:end])
    print()
