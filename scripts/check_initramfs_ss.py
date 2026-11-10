import gzip

with gzip.open('/root/harmony-build/phase1/out/initramfs-boot.img', 'rb') as f:
    data = f.read()

# Find the 'start servicemanager' section with context
idx = data.find(b'start servicemanager')
if idx >= 0:
    start = max(0, idx - 50)
    end = min(len(data), idx + 200)
    print('Around start servicemanager:')
    print(data[start:end])
    print()
    
# Find service system_server definition
idx2 = data.find(b'service system_server')
if idx2 >= 0:
    start2 = max(0, idx2 - 50)
    end2 = min(len(data), idx2 + 150)
    print('Around service system_server:')
    print(data[start2:end2])
