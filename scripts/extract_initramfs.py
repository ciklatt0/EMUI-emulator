import gzip, os, sys

img_path = '/root/harmony-build/phase1/out/initramfs-boot.img'
out_dir = '/tmp/initramfs-check-final'
os.makedirs(out_dir, exist_ok=True)

with gzip.open(img_path, 'rb') as f:
    data = f.read()

offset = 0
while offset < len(data):
    if offset + 110 > len(data):
        break
    header = data[offset:offset+110]
    
    c_magic = header[104:112].decode('ascii')
    if c_magic != '070701':
        break
    
    c_namesize = header[88:96].decode('ascii')
    c_filesize = header[48:56].decode('ascii')
    
    namesize = int(c_namesize, 16)
    filesize = int(c_filesize, 16)
    
    offset += 110
    
    if offset + namesize > len(data):
        break
    
    name = data[offset:offset+namesize].decode('ascii', errors='replace')
    offset += namesize
    
    pad = (4 - (namesize % 4)) % 4
    offset += pad
    
    if name == 'TRAILER!!!':
        break
    
    full_path = os.path.join(out_dir, name.lstrip('/'))
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    
    if filesize > 0:
        with open(full_path, 'wb') as f:
            f.write(data[offset:offset+filesize])
    
    offset += filesize
    
    pad = (4 - (filesize % 4)) % 4
    offset += pad

print(f"Extracted to {out_dir}")

init_path = os.path.join(out_dir, 'init')
if os.path.exists(init_path):
    with open(init_path, 'rb') as f:
        init_data = f.read()
    
    print(f"INIT size: {len(init_data)} bytes")
    
    if b'/dev/kmsg' in init_data:
        print("INIT: /dev/kmsg found in init")
    else:
        print("INIT: /dev/kmsg NOT found in init")
    
    if b'linker64' in init_data:
        print("INIT: linker64 found in init")
    else:
        print("INIT: linker64 NOT found in init")
    
    if b'system_server' in init_data:
        print("INIT: system_server found in init")
    else:
        print("INIT: system_server NOT found in init")
    
    if b"exec 1>/dev/kmsg" in init_data:
        print("INIT: exec 1>/dev/kmsg found")
    else:
        print("INIT: exec 1>/dev/kmsg NOT found")
    
    # Show lines with kmsg
    for line in init_data.split(b'\n'):
        if b'kmsg' in line or b'linker64' in line:
            print(f"  LINE: {line[:100]}")
else:
    print("INIT: init file not found")
