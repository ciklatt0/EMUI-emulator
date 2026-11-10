import os, subprocess

tmpdir = '/tmp/initramfs-check3'
os.makedirs(tmpdir, exist_ok=True)

# Use shell pipeline inside WSL
result = subprocess.run(
    'zcat /root/harmony-build/phase1/out/initramfs-boot.img | cpio -idmv -D ' + tmpdir,
    shell=True, capture_output=True, text=True
)
print("Return code:", result.returncode)
if result.stdout:
    lines = result.stdout.split('\n')
    print(f"Extracted {len([l for l in lines if l.strip()])} entries")

# Check init.rc
init_rc = os.path.join(tmpdir, 'init.rc')
if os.path.exists(init_rc):
    with open(init_rc) as f:
        content = f.read()
    if 'system_server' in content:
        print("\nsystem_server FOUND in initramfs init.rc")
        idx = content.find('service system_server')
        end = content.find('\nservice ', idx + 1)
        if end == -1:
            end = len(content)
        print(content[idx:end])
    else:
        print("\nsystem_server NOT in initramfs init.rc")
else:
    print("init.rc not found in initramfs")
