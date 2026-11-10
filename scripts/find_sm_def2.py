import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Search the main init.rc for servicemanager
init_rc = '/tmp/sys-mnt-evr/init.rc'
if os.path.exists(init_rc):
    with open(init_rc, 'r', errors='ignore') as f:
        content = f.read()
    if 'servicemanager' in content:
        print("=== init.rc ===")
        for i, line in enumerate(content.split('\n'), 1):
            if 'servicemanager' in line.lower():
                print(f"  {i}: {line.strip()}")

# Search all .rc files
for root, dirs, files in os.walk('/tmp/sys-mnt-evr'):
    for f in files:
        if f.endswith('.rc'):
            path = os.path.join(root, f)
            try:
                with open(path, 'r', errors='ignore') as fh:
                    content = fh.read()
                    if 'service servicemanager' in content:
                        print(f"\n=== {path} ===")
                        for i, line in enumerate(content.split('\n'), 1):
                            if 'servicemanager' in line.lower():
                                print(f"  {i}: {line.strip()}")
                        print()
            except:
                pass