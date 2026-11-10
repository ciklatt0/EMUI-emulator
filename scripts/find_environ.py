with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# Find init.environ.rc creation
idx = c.find('init.environ.rc')
if idx != -1:
    # Show surrounding context
    start = max(0, idx - 200)
    end = min(len(c), idx + 800)
    print(c[start:end])
else:
    print('init.environ.rc not found')

