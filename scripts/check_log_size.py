import os
log_path = '/root/harmony-build/logs/boot-zygote-evr.log'
if os.path.exists(log_path):
    size = os.path.getsize(log_path)
    print(f"Log size: {size} bytes")
    with open(log_path) as f:
        lines = f.readlines()
    print(f"Total lines: {len(lines)}")
    # Show last 30 lines
    for line in lines[-30:]:
        print(line.rstrip())
else:
    print("Log file not found")