import struct
import os

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    data = f.read()

file_size = len(data)

# Search for ext4 filesystem magic (0x53EF) - this is at offset 0x438 from partition start
# So partition start = pos - 0x438
ext4_magic = b'\x53\xef'
count = 0
pos = 0
while True:
    pos = data.find(ext4_magic, pos)
    if pos == -1:
        break
    partition_start = pos - 0x438
    if partition_start >= 0:
        # Check if there's a reasonable partition header there
        f_check = open(app_path, 'rb')
        f_check.seek(partition_start)
        header = f_check.read(32)
        f_check.close()
        
        # Check for Huawei magic or other reasonable values
        if header[0:4] == b'\x55\xaa\x5a\xa5':
            print(f"ext4 magic at 0x{pos:08x}, partition start at 0x{partition_start:08x}")
            print(f"  Header at partition start: {header[:16].hex()}")
            count += 1
            if count > 20:
                break
    pos += 1

print(f"\nFound {count} potential ext4 partitions with Huawei header")
