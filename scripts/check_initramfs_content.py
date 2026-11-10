import gzip

with gzip.open('/root/harmony-build/phase1/out/initramfs-boot.img', 'rb') as f:
    data = f.read()

print(f'Decompressed size: {len(data)} bytes')

# Search for key strings
for kw in [b'start system_server', b'service system_server', b'/dev/kmsg', b'EVR-L29: reaching linker64', b'EVR-L29: bind-mount']:
    count = data.count(kw)
    print(f'{kw.decode()}: {count} occurrences')
    if count > 0:
        idx = data.find(kw)
        start = max(0, idx - 30)
        end = min(len(data), idx + len(kw) + 30)
        print(f'  Context: {data[start:end]}')

# Also search for start servicemanager to see if start system_server follows it
idx = data.find(b'start servicemanager')
if idx >= 0:
    print(f'\nstart servicemanager found at {idx}')
    print(f'Next 100 bytes: {data[idx:idx+100]}')
