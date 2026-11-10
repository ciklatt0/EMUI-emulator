import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Search for composer service binaries
for root, dirs, files in os.walk('/tmp/sys-mnt-evr/system'):
    for f in files:
        name = f.lower()
        if 'composer' in name or 'hwcomposer' in name:
            print(os.path.join(root, f))

# Also check vendor
for root, dirs, files in os.walk('/tmp/sys-mnt-evr/vendor'):
    for f in files:
        name = f.lower()
        if 'composer' in name or 'hwcomposer' in name:
            print(os.path.join(root, f))