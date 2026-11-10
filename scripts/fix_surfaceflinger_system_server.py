with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

print("=== Current state ===")
print(f"'start system_server' count: {content.count('start system_server')}")
print(f"'service system_server' count: {content.count('service system_server')}")
print(f"'start surfaceflinger' count: {content.count('start surfaceflinger')}")
print(f"'service surfaceflinger' count: {content.count('service surfaceflinger')}")
print(f"'class_start core' count: {content.count('class_start core')}")

# Fix: Add start surfaceflinger and start system_server right after start servicemanager in init.rc
# This ensures they start when servicemaker starts
old = '''start servicemanager
    start system_server'''

new = '''start servicemanager
    start surfaceflinger
    start system_server'''

count = content.count(old)
print(f"\nFound {count} occurrences of 'start servicemanager\\n    start system_server'")

if count > 0:
    content = content.replace(old, new, 1)
    print("FIX: Added start surfaceflinger after start servicemanager")
else:
    # Try alternative pattern
    old2 = '''start servicemanager'''
    new2 = '''start servicemanager
    start surfaceflinger
    start system_server'''
    if old2 in content:
        # Replace only the first occurrence (the one in init.rc patching section)
        content = content.replace(old2, new2, 1)
        print("FIX: Added start surfaceflinger + system_server after start servicemanager (alt)")
    else:
        print("ERROR: Could not find 'start servicemanager' pattern")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
