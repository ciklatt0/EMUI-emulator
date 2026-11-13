import struct

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    data = f.read(0x200)  # Read first 512 bytes

print("UPDATE.APP Header Analysis (first 512 bytes):")
for i in range(0, len(data), 16):
    chunk = data[i:i+16]
    hex_part = ' '.join(f'{b:02x}' for b in chunk)
    ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
    print(f'{i:04x}: {hex_part:<48} {ascii_part}')

print("\n--- Key offsets ---")
# Offset 0x50: magic
print(f"Offset 0x50: {data[0x50:0x54].hex()} -> {data[0x50:0x54]}")
print(f"Offset 0x54: {struct.unpack('<I', data[0x54:0x58])[0]}")
print(f"Offset 0x58: {struct.unpack('<I', data[0x58:0x5c])[0]}")
print(f"Offset 0x5c: {data[0x5c:0x68]}")
print(f"Offset 0x68: {struct.unpack('<I', data[0x68:0x6c])[0]}")
print(f"Offset 0x6c: {struct.unpack('<I', data[0x6c:0x70])[0]}")
print(f"Offset 0x70: {data[0x70:0x80]}")
print(f"Offset 0x80: {data[0x80:0x90]}")
print(f"Offset 0x90: {data[0x90:0xa0]}")
