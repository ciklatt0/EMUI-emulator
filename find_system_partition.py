import struct

app_path = './UPDATE.APP'

with open(app_path, 'rb') as f:
    data = f.read()

file_size = len(data)

# Search for null-terminated "system" string (7 bytes: s-y-s-t-e-m-\0)
# This would be a partition name in Huawei UPDATE.APP
target = b'system\x00'
pos = 0
count = 0
while True:
    pos = data.find(target, pos)
    if pos == -1:
        break
    # Show context around this occurrence
    start = max(0, pos - 64)
    end = min(file_size, pos + 64)
    chunk = data[start:end]
    hex_part = ' '.join(f'{b:02x}' for b in chunk)
    ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
    print(f"'system\\0' at 0x{pos:08x} ({pos}):")
    print(f"  {hex_part}")
    print(f"  {ascii_part}")
    count += 1
    if count > 20:
        break
    pos += 1

print(f"\nTotal 'system\\0' occurrences shown: {count}")

# Also search for "system.img" or "system_ext"
for target_name in [b'system.img\x00', b'system_ext\x00', b'odm\x00', b'product\x00']:
    pos = 0
    cnt = 0
    while True:
        pos = data.find(target_name, pos)
        if pos == -1:
            break
        print(f"\n'{target_name.decode().rstrip(chr(0))}\\0' at 0x{pos:08x} ({pos}):")
        start = max(0, pos - 32)
        end = min(file_size, pos + 64)
        chunk = data[start:end]
        hex_part = ' '.join(f'{b:02x}' for b in chunk)
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        print(f"  {hex_part}")
        print(f"  {ascii_part}")
        cnt += 1
        pos += 1
        if cnt > 5:
            break
