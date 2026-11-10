import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

sm_path = '/tmp/sys-mnt-evr/system/bin/servicemanager'
result = subprocess.run(['readelf', '-d', sm_path], capture_output=True, text=True)
for line in result.stdout.split('\n'):
    if 'INTERP' in line or 'NEEDED' in line:
        print(f"  {line.strip()}")

# Also check linker64
linker_path = '/tmp/sys-mnt-evr/system/bin/linker64'
if os.path.exists(linker_path):
    print(f"\nlinker64 exists: {os.path.getsize(linker_path)} bytes")
else:
    print(f"\nlinker64 NOT found at /system/bin/linker64")
    # Check symlink
    if os.path.islink(linker_path):
        print(f"  symlink -> {os.readlink(linker_path)}")

# Check apex runtime linker
apex_linker = '/tmp/sys-mnt-evr/apex/com.android.runtime/bin/linker64'
if os.path.exists(apex_linker):
    print(f"apex linker64 exists: {os.path.getsize(apex_linker)} bytes")
else:
    print(f"apex linker64 NOT found")