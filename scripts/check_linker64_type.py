import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Check if /system/bin/linker64 is a symlink or real file
linker64_path = '/tmp/sys-mnt-evr/system/bin/linker64'
if os.path.islink(linker64_path):
    print(f"/system/bin/linker64 is a SYMLINK -> {os.readlink(linker64_path)}")
    print(f"  Target exists: {os.path.exists(linker64_path)}")
elif os.path.exists(linker64_path):
    print(f"/system/bin/linker64 is a REAL FILE ({os.path.getsize(linker64_path)} bytes)")
else:
    print(f"/system/bin/linker64 does not exist")

# Check bootstrap/linker64
bootstrap_linker64 = '/tmp/sys-mnt-evr/system/bin/bootstrap/linker64'
if os.path.islink(bootstrap_linker64):
    print(f"/system/bin/bootstrap/linker64 is a SYMLINK -> {os.readlink(bootstrap_linker64)}")
elif os.path.exists(bootstrap_linker64):
    print(f"/system/bin/bootstrap/linker64 is a REAL FILE ({os.path.getsize(bootstrap_linker64)} bytes)")
else:
    print(f"/system/bin/bootstrap/linker64 does not exist")

# Check what linker64 files exist as real files
print("\n=== All linker64 files ===")
for root, dirs, files in os.walk('/tmp/sys-mnt-evr'):
    for f in files:
        if f == 'linker64':
            full = os.path.join(root, f)
            if os.path.islink(full):
                print(f"  SYMLINK: {full} -> {os.readlink(full)}")
            elif os.path.exists(full):
                print(f"  REAL: {full} ({os.path.getsize(full)} bytes)")