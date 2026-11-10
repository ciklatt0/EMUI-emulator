with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Find APEX_LIST construction
idx = content.find('APEX_LIST=""')
if idx != -1:
    start = idx
    end = min(len(content), idx + 3000)
    print(content[start:end])
