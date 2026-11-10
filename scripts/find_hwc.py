import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Search for hwcomposer in init files
for root_dir in ['/tmp/sys-mnt-evr/etc/init', '/tmp/sys-mnt-evr/vendor/etc/init', '/tmp/sys-mnt-evr/system/etc/init']:
    if not os.path.isdir(root_dir):
        continue
    for root, dirs, files in os.walk(root_dir):
        for f in files:
            path = os.path.join(root, f)
            try:
                with open(path, 'r', errors='ignore') as fh:
                    content = fh.read()
                    if 'hwcomposer' in content.lower():
                        print(f"=== {path} ===")
                        for line in content.split('\n'):
                            if 'hwcomposer' in line.lower():
                                print(f"  {line.strip()}")
                        print()
            except:
                pass