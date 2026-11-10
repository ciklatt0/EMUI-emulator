with open('/root/harmony-build/scripts/81-boot-zygote-lio.sh', 'r') as f:
    lines = f.readlines()
for i, line in enumerate(lines, 1):
    if 'ensure_fake_blocks' in line or 'pin_selinux' in line or 'pin_printk' in line or '### iter=' in line:
        print(f'{i}: {line.rstrip()}')

