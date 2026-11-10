import gzip

with gzip.open('/root/harmony-build/phase1/out/initramfs-boot.img', 'rb') as f:
    data = f.read()

# Find all occurrences of "system_server" with context
idx = 0
count = 0
while True:
    idx = data.find(b'system_server', idx)
    if idx < 0:
        break
    count += 1
    start = max(0, idx - 100)
    end = min(len(data), idx + 100)
    context = data[start:end]
    print(f'Occurrence {count} at byte {idx}:')
    print(f'  {context}')
    print()
    idx += 1

print(f'Total: {count} occurrences')