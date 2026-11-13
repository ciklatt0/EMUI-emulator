import struct
import sys
import os

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    # Read header
    data = f.read(256)
    
    # Check for known Huawei UPDATE.APP magic
    print("First 256 bytes (hex):")
    for i in range(0, min(256, len(data)), 16):
        hex_part = ' '.join(f'{b:02x}' for b in data[i:i+16])
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
        print(f'{i:04x}: {hex_part:<48} {ascii_part}')
