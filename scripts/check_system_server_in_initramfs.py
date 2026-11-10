import gzip

with gzip.open('/root/harmony-build/phase1/out/initramfs-boot.img', 'rb') as f:
    data = f.read()

# Find all occurrences of "start system_server"
idx = 0
count = 0
while True:
    idx = data.find(b'start system_server', idx)
    if idx < 0:
        break
    count += 1
    start = max(0, idx - 80)
    end = min(len(data), idx + 80)
    print(f'Occurrence {count} at byte {idx}:')
    print(f'  {data[start:end]}')
    print()
    idx += 1

print(f'\nTotal: {count} occurrences')

# Also check what's around "start servicemanager"
idx = data.find(b'start servicemanager')
if idx >= 0:
    print(f'\nstart servicemanager at byte {idx}:')
    start = max(0, idx - 50)
    end = min(len(data), idx + 150)
    print(f'  {data[start:end]}')
