with open('/tmp/harmony-emulator-test6.log') as f:
    log = f.read()
print(f"Log size: {len(log)} bytes")
# Check for key events
for kw in ['starting service', 'system_server', 'surfaceflinger', 'servicemanager', 'zygote', 'exited with status', 'EVR-L29']:
    if kw in log:
        print(f"\n=== Found '{kw}' in log! ===")
        idx = log.find(kw)
        print(f"  Context: ...{log[max(0,idx-50):idx+len(kw)+50]}...")
    else:
        print(f"\n'{kw}' NOT found in log")