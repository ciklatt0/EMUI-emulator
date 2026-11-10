import re

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find where start servicemanager is in init.rc section and add start system_server after it
# Look for the init.rc creation section and add start system_server after start servicemanager
old = '''start servicemanager'''
new = '''start servicemanager
    start system_server'''

count = content.count(old)
print(f"Found {count} occurrences of 'start servicemanager'")

# Replace the first occurrence that's in an init.rc context (not in comments)
# Look for it near "action=init" or similar init.rc context
if count > 0:
    # Replace only the first occurrence
    content = content.replace(old, new, 1)
    print("Added start system_server after start servicemanager")
else:
    print("ERROR: start servicemanager not found")

with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'w') as f:
    f.write(content)

print("Done!")
