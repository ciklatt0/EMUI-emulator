with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh', 'r') as f:
    c = f.read()

# Find fix_ldconfig function
idx = c.find('fix_ldconfig()')
if idx != -1:
    # Show from function start to the PATHS section
    end = c.find('NAP=$(/bb/grep', idx)
    if end == -1:
        end = idx + 3000
    print(c[idx:end])
else:
    print('fix_ldconfig not found')
