with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    c = f.read()

# Find all occurrences of init.environ.rc
idx = 0
while True:
    idx = c.find('init.environ.rc', idx)
    if idx == -1:
        break
    start = max(0, idx - 100)
    end = min(len(c), idx + 100)
    print(f'--- at {idx} ---')
    print(repr(c[start:end]))
    idx += 1

