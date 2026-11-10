import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find where init.rc is created (cat > "$ROOT/init.rc")
# Look for service zygote or service system_server definitions
for match in re.finditer(r'(service zygote|service system_server)', content):
    start = max(0, match.start() - 200)
    end = min(len(content), match.end() + 200)
    print(f'--- Position {match.start()} ---')
    print(content[start:end])
    print()
