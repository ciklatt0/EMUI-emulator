import subprocess, os

# Mount system image, check service name, unmount - all in one call
result = subprocess.run(
    'mkdir -p /tmp/sys-check2 && mount -t erofs -o ro /root/harmony-build/evr-super-out/parts/system.img /tmp/sys-check2 2>/dev/null; grep -n "servicemanager\\|servicemaker" /tmp/sys-check2/init.rc 2>/dev/null | head -20; umount /tmp/sys-check2 2>/dev/null',
    shell=True, capture_output=True, text=True
)
print("STDOUT:")
print(result.stdout)
print("STDERR:")
print(result.stderr)
