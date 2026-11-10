import subprocess, os

# Extract gzipped cpio initramfs
tmpdir = '/tmp/initramfs-check'
os.makedirs(tmpdir, exist_ok=True)

# Decompress and extract
result = subprocess.run(
    f'zcat /root/harmony-build/phase1/out/initramfs-boot.img | cpio -idmv -D {tmpdir}',
    capture_output=True, text=True, shell=True
)
print("Return code:", result.returncode)
if result.stdout:
    print("Stdout (first 50 lines):")
    for line in result.stdout.split('\n')[:50]:
        print(f"  {line}")
if result.stderr:
    print("Stderr:", result.stderr[:500])

# Check for system_server in init.rc
init_rc = os.path.join(tmpdir, 'init.rc')
if os.path.exists(init_rc):
    with open(init_rc) as f:
        content = f.read()
    if 'system_server' in content:
        print("\nsystem_server FOUND in initramfs init.rc")
        for line in content.split('\n'):
            if 'system_server' in line:
                print(f"  {line.strip()}")
    else:
        print("\nsystem_server NOT in initramfs init.rc")
        # Show what services ARE defined
        services = [line.strip() for line in content.split('\n') if line.startswith('service ')]
        print(f"Services in init.rc: {len(services)}")
        for s in services[:20]:
            print(f"  {s}")
else:
    print("init.rc not found in initramfs")
