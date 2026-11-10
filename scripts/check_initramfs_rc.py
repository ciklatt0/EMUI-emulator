import os

# Check if initramfs has init.rc
root = '/root/harmony-build/initramfs-boot'
if os.path.isdir(root):
    for entry in os.listdir(root):
        if entry.startswith('init'):
            print(f"  {entry}")
else:
    print(f"initramfs root not found: {root}")

# Check what rc files are in initramfs
for f in ['init.rc', 'init.zygote64_32.rc', 'ueventd.rc', 'init.environ.rc']:
    path = os.path.join(root, f)
    if os.path.exists(path):
        print(f"  FOUND: {path}")
    else:
        print(f"  MISSING: {path}")