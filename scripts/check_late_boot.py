with open('/root/harmony-build/logs/boot-zygote-evr.log') as f:
    lines = f.readlines()
    # Show lines from 240s onwards
    for line in lines:
        if any(kw in line for kw in ['starting service', 'init: starting']):
            # Extract timestamp
            parts = line.split(']')
            if len(parts) > 1:
                ts_str = parts[0].strip('[').strip()
                try:
                    ts = float(ts_str)
                    if ts > 240:
                        print(line.rstrip())
                except:
                    pass