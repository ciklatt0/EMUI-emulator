import os, subprocess, gzip

tmpdir = '/tmp/initramfs-check2'
os.makedirs(tmpdir, exist_ok=True)

# Decompress gzip first
with gzip.open('/root/harmony-build/phase1/out/initramfs-boot.img', 'rb') as f_in:
    with open('/tmp/initramfs-boot.cpio', 'wb') as f_out:
        f_out.write(f_in.read())

print("Decompressed initramfs to /tmp/initramfs-boot.cpio")

# Extract cpio
result = subprocess.run(
    ['cpio', '-idmv', '-D', tmpdir],
    input=open('/tmp/initramfs-boot.cpio', 'rb').read(),
    capture_output=True, text=True
)
print("Return code:", result.returncode)
if result.stdout:
    lines = result.stdout.split('\n')
    print(f"Extracted {len(lines)} entries")
    for line in lines[:20]:
        print(f"  {line}")

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
