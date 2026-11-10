import subprocess
import os

HERE = "/root/harmony-build/scripts"
KERNEL = "/root/harmony-build/phase1/kernel/Image"
OUT = "/root/harmony-build/phase1/out/initramfs-boot.img"
KCMD = "console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true androidboot.serialno=unknown androidboot.zygote=zygote64_32 printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"
QEMU_DISPLAY_OPTS = "-display none"
DISK = "/root/harmony-build/evr-boot/system-disk.img"
RUNLOG = "/tmp/harmony-emulator-test.log"

cmd = f"qemu-system-aarch64 -machine virt,gic-version=3,virtualization=on -cpu max -smp 4 -m 4096 -accel tcg,thread=multi -kernel {KERNEL} -initrd {OUT} -append \"{KCMD}\" {QEMU_DISPLAY_OPTS} -drive \"file={DISK},if=none,format=raw,id=sysdisk,cache=unsafe\" -device virtio-blk-device,drive=sysdisk,bootindex=1 -device virtio-rng-device -device virtio-net-device,netdev=n0 -netdev user,id=n0,hostfwd=tcp::5555-:5555 -monitor none -no-reboot -serial \"file:{RUNLOG}\" </dev/null >/tmp/qemu-stderr.log 2>&1"

print(f"Running QEMU...")
print(f"Command: {cmd}")
print()

result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
print(f"Return code: {result.returncode}")
print(f"Stdout:\n{result.stdout[:2000]}")
print(f"Stderr:\n{result.stderr[:2000]}")

# Check if QEMU produced output
if os.path.exists(RUNLOG):
    with open(RUNLOG) as f:
        log = f.read()
    print(f"\nRUNLOG size: {len(log)} bytes")
    print(f"RUNLOG first 500 chars:\n{log[:500]}")
else:
    print("\nRUNLOG does not exist!")

if os.path.exists("/tmp/qemu-stderr.log"):
    with open("/tmp/qemu-stderr.log") as f:
        stderr = f.read()
    print(f"\nqemu-stderr.log size: {len(stderr)} bytes")
    print(f"qemu-stderr.log content:\n{stderr[:500]}")
else:
    print("\nqemu-stderr.log does not exist!")