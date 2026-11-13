import struct
import os

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    # Search for partition names
    f.seek(0)
    data = f.read()
    
    print(f"File size: {len(data)} bytes")
    
    # Search for common partition names
    for name in [b'system', b'vendor', b'boot', b'recovery', b'cache', b'userdata']:
        pos = 0
        count = 0
        while True:
            pos = data.find(name, pos)
            if pos == -1:
                break
            count += 1
            if count <= 5:
                # Show context around match
                start = max(0, pos - 32)
                end = min(len(data), pos + 64)
                chunk = data[start:end]
                hex_part = ' '.join(f'{b:02x}' for b in chunk)
                ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                print(f"  '{name.decode()}' at offset 0x{pos:08x} ({pos}):")
                print(f"    {hex_part}")
                print(f"    {ascii_part}")
            pos += 1
        if count > 5:
            print(f"  '{name.decode()}' found {count} total times (showing first 5)")
        else:
            print(f"  '{name.decode()}' found {count} time(s)")
