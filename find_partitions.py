import struct

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    data = f.read()

file_size = len(data)
print(f"File size: {file_size} bytes ({file_size / 1024 / 1024:.1f} MB)")

# Search for all occurrences of Huawei UPDATE.APP magic: 55 aa 5a a5
magic = b'\x55\xaa\x5a\xa5'
positions = []
pos = 0
while True:
    pos = data.find(magic, pos)
    if pos == -1:
        break
    positions.append(pos)
    pos += 1

print(f"\nFound {len(positions)} magic occurrences (55 aa 5a a5):")
for i, p in enumerate(positions[:50]):
    # Read what follows the magic
    if p + 20 <= file_size:
        val1 = struct.unpack('<I', data[p+4:p+8])[0]
        val2 = struct.unpack('<I', data[p+8:p+12])[0]
        model = data[p+12:p+18]
        val3 = struct.unpack('<I', data[p+18:p+22])[0]
        val4 = struct.unpack('<I', data[p+22:p+26])[0]
        print(f"  #{i}: offset=0x{p:08x} ({p}), size={val1}, ver={val2}, model={model}, val3=0x{val3:08x}, val4=0x{val4:08x}")
