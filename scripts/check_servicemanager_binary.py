import os, subprocess

os.makedirs('/tmp/sys-mnt-evr', exist_ok=True)
subprocess.run(['mount', '-t', 'erofs', '-o', 'ro', '/root/harmony-build/evr-super-out/parts/system.img', '/tmp/sys-mnt-evr'], capture_output=True)

# Check servicemanager binary and its dependencies
sm_path = '/tmp/sys-mnt-evr/system/bin/servicemanager'
if os.path.exists(sm_path):
    print(f"Found servicemanager at {sm_path}")
    print(f"Size: {os.path.getsize(sm_path)} bytes")
    
    # Check if it's a valid ELF
    with open(sm_path, 'rb') as f:
        magic = f.read(4)
        print(f"ELF magic: {magic}")
    
    # Try readelf
    result = subprocess.run(['readelf', '-d', sm_path], capture_output=True, text=True)
    if result.returncode == 0:
        for line in result.stdout.split('\n'):
            if 'NEEDED' in line:
                print(f"  {line.strip()}")
    else:
        print(f"readelf failed: {result.stderr}")
else:
    print("servicemanager not found at /system/bin/servicemanager")
    # Search for it
    for root, dirs, files in os.walk('/tmp/sys-mnt-evr'):
        for f in files:
            if f == 'servicemanager':
                print(f"Found at: {os.path.join(root, f)}")