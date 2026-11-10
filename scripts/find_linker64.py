import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Search for linker64
for root, dirs, files in os.walk('/tmp/sys-mnt-evr'):
    for f in files:
        if 'linker64' in f or 'linker' in f.lower():
            full = os.path.join(root, f)
            print(full)

# Check what's in /system/bin/
print("\n=== /system/bin/ (first 50) ===")
system_bin = '/tmp/sys-mnt-evr/system/bin'
if os.path.isdir(system_bin):
    for f in sorted(os.listdir(system_bin))[:50]:
        print(f"  {f}")