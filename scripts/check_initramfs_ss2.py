import gzip

with gzip.open('/root/harmony-build/phase1/out/initramfs-boot.img', 'rb') as f:
    data = f.read()

# Find 'start servicemanager' with more context
idx = data.find(b'start servicemanager')
if idx >= 0:
    start = max(0, idx - 300)
    end = min(len(data), idx + 300)
    print('Around start servicemanager (larger context):')
    print(data[start:end])
    print()
    
# Find 'on init' occurrences near system_server
idx2 = data.find(b'on init')
count = 0
while idx2 >= 0 and count < 10:
    start2 = max(0, idx2 - 30)
    end2 = min(len(data), idx2 + 60)
    print(f'on init at byte {idx2}:')
    print(f'  {data[start2:end2]}')
    print()
    idx2 = data.find(b'on init', idx2 + 1)
    count += 1
