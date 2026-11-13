import struct
import os

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    data = f.read()

file_size = len(data)
print(f"File size: {file_size} bytes ({file_size / 1024 / 1024:.1f} MB)")

# Huawei UPDATE.APP typically has a header with magic at start
# Let's look for patterns around known partition names
# Common Huawei partition names in UPDATE.APP:
partitions = [b'system', b'vendor', b'boot', b'recovery', b'cache', b'userdata', 
              b'persist', b'metadata', b'oem', b'dsp', b'modem', b'firmware']

print("\n=== Looking for partition table structures ===")

# Search for patterns: partition name followed by specific byte patterns
# In Huawei UPDATE.APP, partitions often appear as:
# [name][null][some bytes][offset 8 bytes][size 8 bytes] or similar

# Let's look at areas where multiple partition names appear close together
# This would indicate a partition table

for name in partitions:
    pos = 0
    found_positions = []
    while True:
        pos = data.find(name, pos)
        if pos == -1:
            break
        found_positions.append(pos)
        pos += 1
    
    if len(found_positions) > 1:
        # Check if any two occurrences are close together (within 256 bytes)
        for i in range(len(found_positions) - 1):
            gap = found_positions[i+1] - found_positions[i]
            if 10 <= gap <= 512:
                print(f"\n'{name.decode()}' at 0x{found_positions[i]:08x} and next at gap {gap}")
                # Show context
                start = max(0, found_positions[i] - 16)
                end = min(file_size, found_positions[i] + 48)
                chunk = data[start:end]
                hex_part = ' '.join(f'{b:02x}' for b in chunk)
                ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                print(f"  {hex_part}")
                print(f"  {ascii_part}")
                break
