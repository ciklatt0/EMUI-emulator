import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Check all lib64 directories
for search_root in ['/tmp/sys-mnt-evr/system/lib64', '/tmp/sys-mnt-evr/vendor/lib64']:
    if not os.path.isdir(search_root):
        print(f"{search_root}: NOT FOUND")
        continue
    files = os.listdir(search_root)
    print(f"=== {search_root} ({len(files)} files) ===")
    for f in sorted(files):
        print(f"  {f}")
    print()

# Check APEX
apex_runtime = '/tmp/sys-mnt-evr/apex/com.android.runtime/lib64'
if os.path.isdir(apex_runtime):
    files = os.listdir(apex_runtime)
    print(f"=== {apex_runtime} ({len(files)} files) ===")
    for f in sorted(files):
        print(f"  {f}")