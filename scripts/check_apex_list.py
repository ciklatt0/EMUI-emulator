with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find __APEX_LIST__ definition
idx = content.find('__APEX_LIST__')
if idx != -1:
    # Show context
    start = max(0, idx - 200)
    end = min(len(content), idx + 500)
    print(content[start:end])

# Also find APEX_LIST variable
idx2 = content.find('APEX_LIST=')
if idx2 != -1:
    start = max(0, idx2 - 50)
    end = min(len(content), idx2 + 500)
    print("\n--- APEX_LIST= definition ---")
    print(content[start:end])
