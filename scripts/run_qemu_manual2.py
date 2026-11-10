import subprocess
import os

# Read variables from boot script
with open('/root/harmony-build/scripts/81-boot-zygote-evr.sh') as f:
    content = f.read()

# Extract variable values
vars_dict = {}
for line in content.split('\n'):
    line = line.strip()
    if line.startswith('KERNEL=') and not line.startswith('#'):
        vars_dict['KERNEL'] = line.split('=', 1)[1].strip().strip('"')
    elif line.startswith('DISK=') and not line.startswith('#'):
        vars_dict['DISK'] = line.split('=', 1)[1].strip().strip('"')
    elif line.startswith('OUT=') and not line.startswith('#'):
        vars_dict['OUT'] = line.split('=', 1)[1].strip().strip('"')
    elif line.startswith('KCMD=') and not line.startswith('#'):
        vars_dict['KCMD'] = line.split('=', 1)[1].strip().strip('"')
    elif line.startswith('QEMU_DISPLAY_OPTS=') and not line.startswith('#'):
        vars_dict['QEMU_DISPLAY_OPTS'] = line.split('=', 1)[1].strip().strip('"')
    elif line.startswith('RUNLOG=') and not line.startswith('#'):
        vars_dict['RUNLOG'] = line.split('=', 1)[1].strip().strip('"')
    elif line.startswith('HERE=') and not line.startswith('#'):
        vars_dict['HERE'] = line.split('=', 1)[1].strip().strip('"')

print("Variables:")
for k, v in vars_dict.items():
    print(f"  {k} = {v}")

# Build QEMU command
cmd = f"qemu-system-aarch64 -machine virt,gic-version=3,virtualization=on -cpu max -smp 4 -m ${vars_dict.get('QEMU_MEM', '4096')} -accel tcg,thread=multi -kernel {vars_dict.get('KERNEL', '')} -initrd {vars_dict.get('OUT', '')} -append \"{vars_dict.get('KCMD', '')}\" {vars_dict.get('QEMU_DISPLAY_OPTS', '')} -drive \"file={vars_dict.get('DISK', '')},if=none,format=raw,id=sysdisk,cache=unsafe\" -device virtio-blk-device,drive=sysdisk,bootindex=1 -device virtio-rng-device -device virtio-net-device,netdev=n0 -netdev user,id=n0,hostfwd=tcp::5555-:5555 -monitor none -no-reboot -serial \"file:{vars_dict.get('RUNLOG', '')}\" </dev/null >\"{vars_dict.get('HERE', '')}/../logs/qemu-stderr.log\" 2>&1"

print(f"\nFull QEMU command:\n{cmd}")
print()

# Check if files exist
import os
for f in [vars_dict.get('KERNEL', ''), vars_dict.get('OUT', ''), vars_dict.get('DISK', '')]:
    if f and os.path.exists(f):
        print(f"EXISTS: {f} ({os.path.getsize(f)} bytes)")
    elif f:
        print(f"MISSING: {f}")