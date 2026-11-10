import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Search for servicemanager service definition
for root, dirs, files in os.walk('/tmp/sys-mnt-evr/etc/init'):
    for f in files:
        path = os.path.join(root, f)
        try:
            with open(path, 'r', errors='ignore') as fh:
                content = fh.read()
                if 'service servicemanager' in content:
                    print(f"=== {path} ===")
                    for line in content.split('\n'):
                        if 'servicemanager' in line.lower():
                            print(f"  {line.strip()}")
                    print()
        except:
            pass

# Also check hw/ subdirectory
for root, dirs, files in os.walk('/tmp/sys-mnt-evr/etc/init/hw'):
    for f in files:
        path = os.path.join(root, f)
        try:
            with open(path, 'r', errors='ignore') as fh:
                content = fh.read()
                if 'servicemanager' in content.lower():
                    print(f"=== {path} ===")
                    for line in content.split('\n'):
                        if 'servicemanager' in line.lower():
                            print(f"  {line.strip()}")
                    print()
        except:
            pass