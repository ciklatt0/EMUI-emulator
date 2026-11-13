import struct

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    data = f.read()

file_size = len(data)

# Look at entry #14 at offset 0x011daa00 in detail
offset = 0x011daa00
print(f"Entry #14 at offset 0x{offset:08x}:")
chunk = data[offset:offset+256]
for i in range(0, len(chunk), 16):
    hex_part = ' '.join(f'{b:02x}' for b in chunk[i:i+16])
    ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk[i:i+16])
    print(f'{offset+i:08x}: {hex_part:<48} {ascii_part}')

print("\n--- Looking for partition names near each entry ---")

# Search for known partition names near magic entries
partitions = [b'system', b'vendor', b'boot', b'recovery', b'cache', b'userdata', 
              b'persist', b'metadata', b'oem', b'dsp', b'modem', b'firmware',
              b'vbmeta_system', b'vbmeta_vendor']

magic = b'\x55\xaa\x5a\xa5'
for i, p in enumerate(positions if 'positions' in dir() else []):
    pass

# Re-find all magic positions
positions = []
pos = 0
while True:
    pos = data.find(magic, pos)
    if pos == -1:
        break
    positions.append(pos)
    pos += 1

for i, p in enumerate(positions):
    # Look for partition names within 256 bytes after this entry
    search_end = min(file_size, p + 512)
    found_parts = []
    for part_name in partitions:
        ppos = data.find(part_name, p, search_end)
        if ppos != -1:
            found_parts.append((part_name.decode(), ppos - p))
    
    if found_parts:
        print(f"\nEntry #{i} at 0x{p:08x} ({p}):")
        for part_name, rel_pos in found_parts:
            print(f"  Found '{part_name}' at relative offset +{rel_pos}")
            
            # Show context around the partition name
            start = max(p, ppos - 32)
            end = min(file_size, ppos + len(part_name) + 48)
            chunk = data[start:end]
            hex_part = ' '.join(f'{b:02x}' for b in chunk)
            ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
            print(f"  Context: {hex_part}")
            print(f"           {ascii_part}")
