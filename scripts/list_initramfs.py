import os

tmpdir = '/tmp/initramfs-check'
if os.path.exists(tmpdir):
    entries = sorted(os.listdir(tmpdir))
    for e in entries[:50]:
        print(e)
    print(f"... total {len(entries)} entries")
else:
    print("Directory not found")
