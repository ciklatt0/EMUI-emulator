import os

for search_root in ['/tmp/sys-mnt-evr/system/lib64', '/tmp/sys-mnt-evr/vendor/lib64']:
    if not os.path.isdir(search_root):
        continue
    print(f"=== {search_root} ===")
    count = 0
    for f in sorted(os.listdir(search_root)):
        if any(kw in f.lower() for kw in ['egl', 'gl', 'gralloc', 'composer', 'hwui', 'surface', 'gui', 'ui', 'render']):
            print(f"  {f}")
            count += 1
    print(f"  Total matches: {count}")
    print()