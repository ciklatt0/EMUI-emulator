import os
entries = os.listdir('/tmp/sys-check')
for e in sorted(entries)[:30]:
    print(e)
