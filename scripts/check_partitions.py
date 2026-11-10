import subprocess

# Check partition names on the disk image
result = subprocess.run(
    ['sgdisk', '-p', '/root/harmony-build/evr-boot/system-disk.img'],
    capture_output=True, text=True
)
lines = result.stdout.split('\n')
for line in lines:
    if 'com.android' in line or 'apex' in line.lower() or 'system' in line.lower() or 'vendor' in line.lower():
        print(line)
