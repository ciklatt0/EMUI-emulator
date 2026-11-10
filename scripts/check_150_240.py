import sys

with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()

# Show all lines between 150s and 240s
for line in lines:
    # Extract timestamp
    parts = line.split(']')
    if len(parts) > 1:
        ts_str = parts[0].strip('[').strip()
        try:
            ts = float(ts_str)
            if 150 <= ts <= 240:
                print(line.rstrip())
        except:
            pass
