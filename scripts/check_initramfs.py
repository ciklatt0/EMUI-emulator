import subprocess, os

# Unpack initramfs to check contents
initramfs = '/root/harmony-build/phase1/out/initramfs-boot.img'
tmpdir = '/tmp/initramfs-check'

os.makedirs(tmpdir, exist_ok=True)

# Extract cpio
result = subprocess.run(
    ['cpio', '-idmv', '<', initramfs],
    capture_output=True, text=True,
    cwd=tmpdir,
    shell=True
)
print("Extract result:", result.returncode)
if result.stderr:
    print("Stderr:", result.stderr[:500])

# Check for system_server in init.rc
init_rc = os.path.join(tmpdir, 'init.rc')
if os.path.exists(init_rc):
    with open(init_rc) as f:
        content = f.read()
    if 'system_server' in content:
        print("system_server FOUND in init.rc")
        for line in content.split('\n'):
            if 'system_server' in line:
                print(f"  {line.strip()}")
    else:
        print("system_server NOT in init.rc")
else:
    print("init.rc not found in initramfs")

# Check init.zygote64_32.rc
zygote_rc = os.path.join(tmpdir, 'init.zygote64_32.rc')
if os.path.exists(zygote_rc):
    with open(zygote_rc) as f:
        content = f.read()
    if 'system_server' in content:
        print("system_server FOUND in init.zygote64_32.rc")
        for line in content.split('\n'):
            if 'system_server' in line:
                print(f"  {line.strip()}")
    else:
        print("system_server NOT in init.zygote64_32.rc")
else:
    print("init.zygote64_32.rc not found in initramfs")
