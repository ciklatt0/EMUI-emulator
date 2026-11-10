import subprocess

# Read QEMU command from script
with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    lines = f.readlines()

# Find the actual QEMU command (not commented)
qemu_cmd_parts = []
in_qemu = False
for line in lines:
    stripped = line.strip()
    if stripped.startswith('#'):
        continue
    if 'qemu-system-aarch64' in stripped:
        in_qemu = True
    if in_qemu:
        if stripped.endswith('\\'):
            qemu_cmd_parts.append(stripped.rstrip('\\').strip())
        else:
            qemu_cmd_parts.append(stripped.strip())
            break

cmd = ' '.join(qemu_cmd_parts)
print(f"QEMU command: {cmd}")
print()

# Run QEMU directly
result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
print(f"Return code: {result.returncode}")
print(f"Stdout:\n{result.stdout[:2000]}")
print(f"Stderr:\n{result.stderr[:2000]}")