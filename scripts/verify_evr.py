import os, struct

parts_dir = '/root/harmony-build/evr-super-out/parts'
for name in sorted(os.listdir(parts_dir)):
    path = os.path.join(parts_dir, name)
    sz = os.path.getsize(path)
    with open(path, 'rb') as f:
        f.seek(1024)
        sb = f.read(16)
    magic = struct.unpack('<I', sb[:4])[0]
    is_erofs = magic & 0xFFFFFF00 == 0xE0F5E100
    print(f'{name:<14} {sz/1024**3:7.3f} GB  EROFS={"VAR" if is_erofs else "YOK"}  magic=0x{magic:08X}')
