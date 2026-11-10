import subprocess
import os
import time

KERNEL = "/root/harmony-build/phase1/kernel/Image"
OUT = "/root/harmony-build/phase1/out/initramfs-boot.img"
KCMD = "console=ttyAMA0,115200 console=tty0 rdinit=/init panic=10 security=selinux enforcing=0 androidboot.hardware=qemu androidboot.selinux=permissive androidboot.debuggable=1 androidboot.secure=0 androidboot.hwcrypto.enabled=true androidboot.serialno=unknown androidboot.zygote=zygote64_32 printk_ratelimit=1000000 printk_ratelimit_burst=1000000 loglevel=7"
DISK = "/root/harmony-build/evr-boot/system-disk.img"
RUNLOG = "/tmp/harmony-emulator-test7.log"

cmd = [
    "qemu-system-aarch64",
    "-machine", "virt,gic-version=3,virtualization=on",
    "-cpu", "max",
    "-smp", "4",
    "-m", "4096",
    "-accel", "tcg,thread=multi",
    "-kernel", KERNEL,
    "-initrd", OUT,
    "-append", KCMD,
    "-display", "none",
    "-drive", f"file={DISK},if=none,format=raw,id=sysdisk,cache=unsafe",
    "-device", "virtio-blk-device,drive=sysdisk,bootindex=1",
    "-device", "virtio-rng-device",
    "-device", "virtio-net-device,netdev=n0",
    "-netdev", "user,id=n0,hostfwd=tcp::5555-:5555",
    "-monitor", "none",
    "-no-reboot",
    "-serial", f"file:{RUNLOG}"
]

print(f"Running QEMU for 15 seconds...")
result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
print(f"Return code: {result.returncode}")

if os.path.exists(RUNLOG):
    with open(RUNLOG) as f:
        log = f.read()
    print(f"RUNLOG size: {len(log)} bytes")
    if len(log) > 0:
        print(f"RUNLOG last 500 chars:\n{log[-500:]}")
else:
    print("RUNLOG does not exist!")